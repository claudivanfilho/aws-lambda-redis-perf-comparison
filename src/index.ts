"use strict";

import Redis from "ioredis";

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: +process.env.REDIS_PORT!,
  password: process.env.REDIS_PASS,
});

const redis2 = new Redis(process.env.REDIS_DB_PATH!);

export const handler = async (event: any) => {
  const time1 = Date.now();
  await redis.set("test", "1");
  const time2 = Date.now();
  await redis2.set("test", "1");
  const time3 = Date.now();

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "Hello, Serverless World!",
      redisEC2: time2 - time1,
      redisUPSTASH: time3 - time2,
    }),
  };
};
