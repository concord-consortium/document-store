const { Pool } = require("pg");
const Cursor = require("pg-cursor")
const admin = require("firebase-admin");
const crypto = require("crypto");
const AWS = require("aws-sdk");
const fs = require("fs");

// === CONFIGURATION
// This script will first check if file already exists in S3 and Firestore. Default behavior is not to overwrite
// anything if it's already present. Change this variable to true to force updates.
const forceUpdate = false;
// S3 config
// credentials should be provided using default env variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
const region = "us-east-1";
const bucket = "models-resources";
const documentsFolder = "cfm-shared" ; // it should match value specified in token-service tool configuration
const redirectsFolder = "legacy-document-store";

// Token-Service / Firestore config
const tokenServiceEnv = "production";
const tokenServiceCollection = "resources";
const tokenServiceTool = "cfm-shared";

// Admin SDK key file file should be placed in this directory and named key.json. It's exactly the same file
// that is necessary for local development of token-service. If you don't have it, take a look
// at "Set up admin credentials" steps described here:
// https://github.com/concord-consortium/token-service#basic-firebase-setup-done-once

// Doc-Store DB connection configuration.
const connectionString = process.env.DATABASE_URL;
// How many rows will be read at once by Postgres Cursor. Note that all the rows will be processed concurrently
// so probably it's better to keep this value small.
const batchSize = 10;

const errorFile = "./migration-errors.log";
const logFile = "./migration.log";
// === END OF CONFIGURATION

if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
  console.log("Missing AWS configuration, set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env variables");
  process.exit(1);
}
if (!process.env.DATABASE_URL) {
  console.log("Missing Document Store Postgres DB connection string in DATABASE_URL env variable. Generate it using `heroku pg:credentials:url -a document-store`.");
  process.exit(1);
}

const readWriteTokenPrefix = "read-write-token:"; // based on token-service code, necessary
const customReadWriteTokenPrefix = "doc-store-imported:" // not necessary, but just to differentiate from token-service generated RW tokens

const pool = new Pool({
  connectionString: connectionString,
  ssl: { rejectUnauthorized: false }
});

admin.initializeApp();
const db = admin.firestore();

const s3 = new AWS.S3({ region });

let errorsCount = 0;

const logError = (message, err) => {
  fs.appendFileSync(errorFile, message + "\n");
  fs.appendFileSync(errorFile, err.stack + "\n\n");
  errorsCount += 1;
}

const log = (message) => {
  fs.appendFileSync(logFile, message);
  process.stdout.write(message);
}

const run = async () => {
  // Cleanup log files.
  fs.writeFileSync(errorFile, "");
  fs.writeFileSync(logFile, "");
  const stats = {
    processed: 0,
    firestoreWrites: 0,
    firestoreSkipped: 0,
    noWriteKey: 0,
    s3UploadsNewFile: 0,
    s3UploadsUpdatedFile: 0,
    s3Skipped: 0,
    s3RedirectObjs: 0,
    updatedReadAccessKeyDocIds: []
  };

  const client = await pool.connect();
  const countRes = await client.query("SELECT Count(*) FROM documents WHERE shared = true");
  log(`${countRes.rows[0].count} shared documents to process\n`);

  const cursor = client.query(new Cursor(`
    SELECT documents.*, document_contents.content, document_contents.updated_at as content_updated_at
    FROM documents
    INNER JOIN document_contents ON document_contents.document_id = documents.id
    WHERE documents.shared = true
  `));

  const read = () => {
    cursor.read(batchSize, async (err, rows) => {
      if (err) {
        console.error("DB read error", err);
        process.exit(1);
      }

      log(".");
      if (stats.processed % 1000 === 0 && stats.processed > 0) {
        log(`${stats.processed} documents have been processed.\n`)
      }

      await Promise.all(rows.map(async row => {
        const rowWithoutContent = Object.assign({}, row, {content: undefined});
        // FOR CFM dev: these lines should be reviewed while implementing CFM-side.
        const readWriteKey = row.read_write_access_key || row.run_key;
        // Read write token in CFM needs to be generated using the same logic.
        const readWriteToken = readWriteTokenPrefix + customReadWriteTokenPrefix + readWriteKey;
        const oldDocumentId = row.id;
        let newDocumentId = row.read_access_key;
        if (!newDocumentId) {
          // read_access_key is sometimes missing. In this case, generate it using 1-way hashing function from
          // read-write key or just generate a new one (document will be read-only).
          if (readWriteKey) {
            newDocumentId = crypto.createHash("sha256").update(readWriteKey).digest("hex");
          } else {
            newDocumentId = crypto.randomBytes(32).toString("hex");
            try {
              // Save generated documentId so if the script is run next time, we won't generate a new one and we
              // won't have to update a file again to S3.
              await pool.query("UPDATE documents SET read_access_key = $1 WHERE id = $2", [newDocumentId, row.id]);
              stats.updatedReadAccessKeyDocIds.push(row.id);
            } catch (e) {
              logError(`DocStore DB read_access_key update failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
            }
          }
        }

        // Create Firestore doc only if there's any kind of read write key. Otherwise, it doesn't make sense.
        if (readWriteKey) {
          try {
            const docRef = db.collection(`${tokenServiceEnv}:${tokenServiceCollection}`).doc(newDocumentId);
            const doc = await docRef.get();
            if (!doc.exists || forceUpdate) {
              try {
                await docRef.set({
                  type: "s3Folder",
                  tool: tokenServiceTool,
                  name: row.title || `imported-doc-${row.id}`,
                  description: "legacy document-store shared document",
                  accessRules: [{
                    type: "readWriteToken",
                    readWriteToken
                  }]
                });
                stats.firestoreWrites += 1;
              } catch (e) {
                logError(`Firestore upload failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
              }
            } else {
              stats.firestoreSkipped += 1;
            }
          } catch (e) {
            logError(`Firestore read failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
          }
        } else {
          stats.noWriteKey += 1;
        }

        // Document content should be ALWAYS uploaded to S3, even if there's no read-write key. In such case,
        // the document will be read-only.
        let uploadResult;
        const key = `${documentsFolder}/${newDocumentId}/file.json`;

        const uploadToS3 = async () => {
          try {
            uploadResult = await s3.upload({
              Bucket: bucket,
              Key: key,
              Body: JSON.stringify(row.content, null, 2),
              ContentType: 'application/json',
              ContentEncoding: 'UTF-8',
              CacheControl: 'no-cache'
            }).promise();
          } catch (e) {
            logError(`S3 upload failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e)
          }
        }

        if (forceUpdate) {
          await uploadToS3();
          stats.s3UploadsNewFile += 1;
        } else {
          try {
            // This is a fast way to check if the object exists in the specified bucket/folder. It'll only download metadata.
            const metadata = await s3.headObject({
              Bucket: bucket,
              Key: key,
            }).promise();
            // Object exists, check timestamps. Upload file to S3 only if it has been modified in DocStore recently.
            // Note that system timezone MUST be set to UTC (that's why there's TZ=UTC in package.json script).
            // Otherwise, pg-node will parse date assuming system timezone and results will be incorrect.
            if (row.content_updated_at > metadata.LastModified) {
              await uploadToS3();
              stats.s3UploadsUpdatedFile += 1;
            } else {
              stats.s3Skipped += 1;
            }
          } catch (e) {
            if (e.code === "NotFound") {
              // Object doesn't exist, upload file.
              await uploadToS3();
              stats.s3UploadsNewFile += 1;
            } else {
              logError(`S3 headObject failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
            }
          }
        }

        if (uploadResult) {
          // Note that redirects work ONLY if AWS S3 Website endpoint is used: ${bucket_name}.s3-website.${region}.amazonaws.com
          // Not the default endpoint: ${bucket_name}.s3.amazonaws.com or ${bucket_name}.s3.${region}.amazonaws.com).
          // See: https://stackoverflow.com/a/22750923
          // On the CFM side when legacy ID is detected, use following URL:
          // http://<bucket-name>.s3-website-us-east-1.amazonaws.com/legacy-document-store/<legacy-ID>
          // Cloudfront can also be used if it points to the website endpoint (this is currently not true for
          // models-resources.concord.org Cloudfront distribution).
          try {
            await s3.putObject({
              Bucket: bucket,
              Key: `${redirectsFolder}/${oldDocumentId}`,
              WebsiteRedirectLocation: `/${uploadResult.Key}`
            }).promise();
            stats.s3RedirectObjs += 1;
          } catch (e) {
            logError(`S3 create redirect object failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
          }
        }
      }));

      if (rows.length > 0) {
        stats.processed += batchSize;
        read();
      } else {
        log(`\nStats: ${JSON.stringify(stats, null, 2)}\n`);
        log(`There have been ${errorsCount} errors while migrating legacy documents. Check migration-errors.log file.\n`);
        process.exit(0);
      }
    });
  }

  log(`Reading doc store data. Every printed . means that ${batchSize} docs have been processed.\n`);
  read();
}

run();
