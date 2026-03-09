const express = require("express");
const redis = require("redis");

const app = express();
app.use(express.json());

const client = redis.createClient({
  url: `redis://${process.env.REDIS_HOST}:6379`
});

client.connect();

app.get("/health", (req, res) => {
  res.status(200).json({ status: "healthy" });
});

app.get("/status", async (req, res) => {
  const time = new Date();
  res.json({
    status: "running",
    time: time
  });
});

app.post("/process", async (req, res) => {
  const data = req.body;

  await client.set("lastProcess", JSON.stringify(data));

  res.json({
    message: "Data processed",
    data: data
  });
});

app.listen(3000, () => {
  console.log("Server running on port 3000");
});