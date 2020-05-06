const { Pool } = require("pg");
const Cursor = require("pg-cursor")
const fs = require("fs");

// === CONFIGURATION
// Doc-Store DB connection configuration.
const connectionString = process.env.DATABASE_URL;
const batchSize = 1000; // how many rows will be read at once by Postgres Cursor.

const errorFile = "./stats-errors.log";
const logFile = "./stats.log";
// === END OF CONFIGURATION

if (!process.env.DATABASE_URL) {
  console.log("Missing Document Store Postgres DB connection string in DATABASE_URL env variable. Generate it using `heroku pg:credentials:url -a document-store`.");
  process.exit(1);
}

const pool = new Pool({
  connectionString: connectionString,
  ssl: { rejectUnauthorized: false }
});

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
  const countRes = await client.query("SELECT Count(*) FROM documents");
  log(`${countRes.rows[0].count} shared documents to process\n`);

  const docsCount = 100;
  let stats = {
    shared: [{sizeInMB: 0}],
    private: [{sizeInMB: 0}]
  }

  const cursor = client.query(new Cursor(`
    SELECT LENGTH(CAST(content AS VARCHAR)) as contentlength, documents.id, documents.shared, document_contents.created_at, document_contents.updated_at
    FROM document_contents 
    INNER JOIN documents ON document_contents.id = documents.id
  `));

  const read = () => {
    cursor.read(batchSize, (err, rows) => {
      if (err) {
        logError("DB read error", err);
      }

      log(".");

      rows.forEach(row => {
        const biggestDocs = row.shared ? stats.shared : stats.private;
        const sizeInMB = row.contentlength / 2**20;
        if (sizeInMB > biggestDocs[biggestDocs.length - 1].sizeInMB) {
          biggestDocs.push({ id: row.id, sizeInMB, updatedAt: row.updated_at, createdAt: row.created_at });
          biggestDocs.sort((a, b) => b.sizeInMB - a.sizeInMB);
          if (biggestDocs.length > docsCount) {
            biggestDocs.length = docsCount;
          }
        }
      });

      if (rows.length > 0) {
        read();
      } else {
        log(`\nStats: ${JSON.stringify(stats, null, 2)}\n`);
        process.exit(0);
      }
    });
  }

  log(`Reading doc store data. Every printed . means that ${batchSize} docs have been processed.\n`);
  read();
}

run();
