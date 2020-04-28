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

  const docsCount = 50;
  let biggestDocs = [0];

  const cursor = client.query(new Cursor(`
    SELECT LENGTH(CAST(content AS VARCHAR)) as contentlength
    FROM document_contents 
  `));

  const read = () => {
    cursor.read(batchSize, (err, rows) => {
      if (err) {
        logError("DB read error", err);
      }

      log(".");

      rows.forEach(row => {
        const len = Number(row.contentlength);
        if (len > biggestDocs[biggestDocs.length - 1]) {
          biggestDocs.push(len);
          biggestDocs = biggestDocs.sort((a, b) => a - b).reverse();
          if (biggestDocs.length > docsCount) {
            biggestDocs.length = docsCount;
          }
        }
      });

      if (rows.length > 0) {
        read();
      } else {
        log(`\nThe biggest documents: ${biggestDocs.map(v => (v/1e6).toFixed(3) + "MB").toString()}\n`);
        process.exit(0);
      }
    });
  }

  log(`Reading doc store data. Every printed . means that ${batchSize} docs have been processed.\n`);
  read();
}

run();
