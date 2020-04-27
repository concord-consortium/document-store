const { Pool } = require("pg");
const Cursor = require("pg-cursor")
const admin = require("firebase-admin");
const crypto = require("crypto");
const AWS = require("aws-sdk");
const fs = require("fs");

// === CONFIGURATION
// S3 config
// credentials should be provided using default env variables: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
const region = "us-east-1";
const bucket = "models-resources";
const documentsFolder = "cfm-shared-documents" ; // it should match value specified in token-service tool configuration
const redirectsFolder = "legacy-document-store";
const cloudfront = "https://models-resources.concord.org";

// Token-Service / Firestore config
const tokenServiceEnv = "staging";
const tokenServiceCollection = "resources";
const tokenServiceTool = "cfm-shared";

// Admin SDK key file file should be placed in this directory and named key.json. It's exactly the same file
// that is necessary for local development of token-service. If you don't have it, take a look
// at "Set up admin credentials" steps described here:
// https://github.com/concord-consortium/token-service#basic-firebase-setup-done-once

// Doc-Store DB connection configuration.
const connectionString = process.env.DATABASE_URL;
const batchSize = 10; // how many rows will be read at once by Postgres Cursor.

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

  const client = await pool.connect();
  const countRes = await client.query("SELECT Count(*) FROM documents WHERE shared = true ");
  log(`${countRes.rows[0].count} shared documents to process\n`);

  const cursor = client.query(new Cursor(`
    SELECT documents.*, document_contents.content
    FROM documents
    INNER JOIN document_contents ON document_contents.id = documents.id
    WHERE documents.shared = true 
  `));

  const read = () => {
    cursor.read(batchSize, (err, rows) => {
      if (err) {
        logError("DB read error", err);
      }

      log(".");

      rows.forEach(async row => {
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
          }
        }

        // Create Firestore doc only if there's any kind of read write key. Otherwise, it doesn't make sense.
        if (readWriteKey) {
          try {
            await db.collection(`${tokenServiceEnv}:${tokenServiceCollection}`).doc(newDocumentId).set({
              type: "s3Folder",
              tool: tokenServiceTool,
              name: row.title || `imported-doc-${row.id}`,
              description: "legacy document-store shared document",
              accessRules: [{
                type: "readWriteToken",
                readWriteToken
              }]
            });
          } catch (e) {
            logError(`Firestore upload failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
          }
        }

        // Document content should be ALWAYS uploaded to S3, even if there's no read-write key. In such case,
        // the document will be read-only.
        let uploadResult;
        try {
          uploadResult = await s3.upload({
            Bucket: bucket,
            Key: `${documentsFolder}/${newDocumentId}/file.json`,
            Body: JSON.stringify(row.content, null, 2),
            ContentType: 'application/json',
            ContentEncoding: 'UTF-8',
            CacheControl: 'no-cache'
          }).promise()
        } catch (e) {
          logError(`S3 upload failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
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
              // We could also use relative path here, as both redirect object and the target object are in the same bucket.
              // But absolute URL guarantees that user will be redirected to Cloudfront URL, no matter what base URL has been
              // used to access the redirect object (s3 website endpoint or Cloudfront URL). Actually, I'm not even sure
              // whether Cloudfront hostname would be maintained after the redirect.
              WebsiteRedirectLocation: `${cloudfront}/${uploadResult.Key}`
            }).promise()
          } catch (e) {
            logError(`S3 create redirect object failed for document ${JSON.stringify(rowWithoutContent, null, 2)}`, e);
          }
        }
      });

      if (rows.length > 0) {
        read();
      } else {
        log(`There have been ${errorsCount} errors while migrating legacy documents. Check migration-errors.log file.`);
        process.exit(0);
      }
    });
  }

  log(`Reading doc store data. Every printed . means that ${batchSize} docs have been processed.\n`);
  read();
}

run();
