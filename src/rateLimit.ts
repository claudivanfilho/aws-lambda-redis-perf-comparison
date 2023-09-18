import RateLimiter from "async-ratelimiter";
import { Redis } from "ioredis";

export const PLAN_PREFIX = "plan_company_";
const BLOCK_TIME = 5000;
const blockedCompanies: { [key: string]: number } = {};

const FREE_PLAN = {
  max: 5,
  duration: 10_000,
  monthlyQuota: 1_000,
};

const PAID_PLAN = {
  max: 60,
  duration: 10_000,
  monthlyQuota: 5_000,
};

function getLimiter(plan: string, red: Redis) {
  if (plan === "paid") {
    return new RateLimiter({
      db: red,
      max: PAID_PLAN.max,
      duration: PAID_PLAN.duration,
    });
  }
  return new RateLimiter({
    db: red,
    max: FREE_PLAN.max,
    duration: FREE_PLAN.duration,
  });
}

export async function validateRateLimitAndQuota(companyId: string, red: Redis) {
  if (!companyId) throw new Error("companyId not provided");

  const now = Date.now();
  if (companyId in blockedCompanies && blockedCompanies[companyId] + BLOCK_TIME > now) {
    throw new Error("Rate limit reached");
  }

  const plan: string | null = await red.get(`${PLAN_PREFIX}${companyId}`);
  if (!plan) throw new Error("companyId does not have a plan attached");

  const limiter = await getLimiter(plan, red).get({ id: companyId });

  if (!limiter.remaining) {
    blockedCompanies[companyId] = now;
    throw new Error("Rate limit reached");
  }

  const isOk = await checkMonthlyQuota(companyId, plan, red);
  if (!isOk) throw new Error("Monthly quota reached");

  return limiter;
}

async function checkMonthlyQuota(companyId: string, plan: string, red: Redis) {
  const currentDate = new Date();
  const currentMonth = currentDate.getMonth() + 1; // Months are 0-based, so add 1

  const key = `quota:${companyId}:${currentMonth}`;
  const quota = plan === "paid" ? PAID_PLAN.monthlyQuota : FREE_PLAN.monthlyQuota; // Monthly quota limit

  // Increment the request count for the current month
  await red.incr(key);

  // Get the current request count for the month
  const requestCount = await red.get(key);

  // Check if the quota has been exceeded
  if (+requestCount! > quota) {
    return false; // Quota exceeded
  }

  return true; // Quota not exceeded
}
