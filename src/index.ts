"use strict";

import Redis from "ioredis";
import { PLAN_PREFIX, validateRateLimitAndQuota } from "./rateLimit";

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: +process.env.REDIS_PORT!,
  password: process.env.REDIS_PASS,
});

const redis2 = new Redis(process.env.REDIS_DB_PATH!);

export const handler = async (event: any) => {
  await redis.set(`${PLAN_PREFIX}1`, "free");
  let error;
  const time1 = Date.now();
  await validateRateLimitAndQuota("1", redis).catch((err) => (error = err.message));
  const time2 = Date.now();
  await validateRateLimitAndQuota("1", redis2).catch((err) => (error = err.message));
  const time3 = Date.now();

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: "Hello, Serverless World!",
      redisEC2: time2 - time1,
      redisUPSTASH: time3 - time2,
      error,
    }),
  };
};
