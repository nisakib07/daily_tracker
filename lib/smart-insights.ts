"use client";

import type { Transaction } from "@/lib/types";
import { startOfMonth, endOfMonth, subMonths, subDays, format } from "date-fns";

// ==========================================
// SMART CATEGORY SUGGESTIONS
// ==========================================

// Keyword to category mappings for auto-suggestion (Bangladeshi context)
export const CATEGORY_KEYWORDS: Record<string, string[]> = {
  // Transport
  Transport: [
    // Ride-sharing & Taxi
    "uber", "pathao", "obhai", "shohoz", "indrive", "grab", "ola", "taxi", "cab",
    // Public transport
    "bus", "rickshaw", "cng", "auto", "tempo", "leguna", "train", "metro", "rail",
    // Fuel & Vehicle
    "fuel", "petrol", "diesel", "octane", "gas station", "pump", "parking", "toll",
    "garage", "mechanic", "servicing", "car wash", "tire", "tyre", "oil change",
    // Air travel
    "flight", "airplane", "airport", "biman", "usb", "novoair", "ticket"
  ],
  
  // Food & Dining
  Food: [
    // Meals
    "restaurant", "cafe", "coffee", "lunch", "dinner", "breakfast", "snack", "brunch",
    "dine", "eat", "meal", "food", "hungry", "order", "takeout", "delivery",
    // Fast food & Chains
    "pizza", "burger", "kfc", "bfc", "pizza hut", "dominos", "mcdonalds", "subway",
    "chillox", "takeout", "fakruddin", "star kabab", "sultan", "nanna",
    // Food types
    "biryani", "chinese", "thai", "indian", "italian", "mexican", "sushi", "bbq",
    "kacchi", "tehari", "polao", "korma", "halim", "fuchka", "chotpoti", "jhalmuri",
    // Drinks
    "tea", "cha", "juice", "lassi", "coffee shop", "starbucks", "costa", "north end",
    // Hotels (restaurant context in BD)
    "hotel", "canteen", "mess", "dhaba"
  ],
  
  // Groceries
  Groceries: [
    // Supermarkets
    "agora", "swapno", "shwapno", "meena", "unimart", "lavender", "dhali", "nandan",
    "sobji", "mudi", "dokan", "market", "bazar", "kacha bazar", "kitchen market",
    // Items
    "grocery", "vegetables", "fruits", "milk", "bread", "rice", "chal", "atta",
    "meat", "fish", "chicken", "murgi", "egg", "dim", "oil", "tel", "salt", "sugar",
    "chini", "dal", "moshla", "spice", "potato", "alu", "onion", "peyaj", "garlic",
    // Daily needs
    "daily shopping", "kitchen", "household", "toiletries", "cleaning", "detergent",
    "soap", "shampoo", "tissue", "paper"
  ],
  
  // Shopping
  Shopping: [
    // E-commerce
    "daraz", "evaly", "amazon", "alibaba", "aliexpress", "pickaboo", "rokomari",
    "chaldal", "othoba", "ajkerdeal", "bagdoom", "priyoshop", "startech", "ryans",
    // Clothing
    "clothing", "shirt", "pant", "jeans", "t-shirt", "polo", "jacket", "hoodie",
    "shoes", "sandal", "boots", "sneakers", "bag", "backpack", "watch", "belt",
    // Fashion brands
    "aarong", "yellow", "rang", "cats eye", "apex", "bata", "lotto", "infinity",
    "fashion", "dress", "sharee", "saree", "panjabi", "kurta", "kurti", "salwar",
    // Electronics
    "electronics", "phone", "mobile", "laptop", "computer", "pc", "tablet", "ipad",
    "gadget", "headphone", "earphone", "charger", "cable", "accessories",
    // Others
    "jewelry", "gold", "gift", "present", "toy", "decor", "furniture", "home"
  ],
  
  // Bills & Utilities
  Bills: [
    // Electricity
    "electricity", "desco", "dpdc", "pdb", "nesco", "bpdb", "electric bill", "current",
    // Water
    "water", "wasa", "water bill", "pani",
    // Gas
    "gas bill", "titas", "bakhrabad", "jalalabad", "karnaphuli", "sundarban",
    // Internet & Phone
    "internet", "wifi", "broadband", "link3", "amber", "carnival", "isp", "data pack",
    "phone bill", "mobile bill", "recharge", "flexiload",
    "grameenphone", "gp", "robi", "banglalink", "bl", "airtel", "teletalk",
    // Subscriptions
    "subscription", "netflix", "spotify", "youtube", "prime", "hoichoi", "bongo",
    "chorki", "iqiyi", "disney", "hbo", "apple music", "premium"
  ],
  
  // Healthcare
  Healthcare: [
    // Medical professionals
    "doctor", "dr", "specialist", "consultant", "surgeon", "dentist", "eye doctor",
    // Facilities
    "hospital", "clinic", "diagnostic", "lab", "test", "pathology", "x-ray", "mri",
    "ct scan", "ultrasound", "ecg", "blood test", "urine test", "checkup",
    // BD Hospitals
    "apollo", "popular", "ibn sina", "labaid", "square", "united", "evercare",
    "asgar ali", "birdem", "national heart", "dmch", "suhrawardy", "somo", "east west",
    // Pharmacy & Medicine
    "medicine", "pharmacy", "oushodh", "tablet", "capsule", "syrup", "injection",
    "prescription", "treatment", "therapy", "physiotherapy", "operation", "surgery",
    // Health items
    "vitamin", "supplement", "pain killer", "antibiotic", "ointment", "bandage"
  ],
  
  // Entertainment
  Entertainment: [
    // Cinema & Movies
    "movie", "cinema", "film", "star cineplex", "blockbuster", "shyamoli", "jamuna",
    // Activities
    "concert", "show", "event", "ticket", "game", "gaming", "playstation", "xbox",
    "sports", "cricket", "football", "match", "stadium", "tournament",
    // Fitness
    "gym", "fitness", "yoga", "exercise", "workout", "swimming", "pool",
    // Social
    "club", "party", "celebration", "hangout", "outing", "picnic", "tour", "trip",
    // Streaming & Gaming
    "pubg", "free fire", "cod", "valorant", "steam", "playstation plus", "game pass"
  ],
  
  // Education
  Education: [
    // Institutions
    "school", "college", "university", "varsity", "coaching", "tuition", "private",
    // Fees
    "fee", "admission", "semester", "exam", "registration", "form fill up",
    // Materials
    "book", "boi", "stationery", "notebook", "pen", "pencil", "khata", "guide",
    // Online learning
    "udemy", "coursera", "skillshare", "youtube premium", "masterclass", "10ms",
    "course", "training", "workshop", "seminar", "certificate", "degree"
  ],
  
  // Rent & Housing
  Rent: [
    "rent", "house rent", "flat rent", "apartment rent", "basha bhara", "bhara",
    "landlord", "malik", "bari", "basha", "flat", "sublet", "mess", "hostel",
    "security deposit", "advance", "utility", "service charge", "maintenance", "bua",
  ],
  
  // Salary & Income
  Salary: [
    "salary", "beton", "wage", "payroll", "payment received", "income",
    "bonus", "incentive", "overtime", "ot", "commission", "allowance",
    "festival bonus", "eid bonus", "yearly bonus", "arrear", "increment"
  ],
  
  // Freelance & Side Income
  Freelance: [
    "freelance", "upwork", "fiverr", "freelancer", "toptal", "99designs",
    "client payment", "project payment", "gig", "remote work", "contract",
    "consultancy", "consulting", "side hustle", "part time", "extra income"
  ],
  
  // Investment & Savings
  Investment: [
    // Stock market
    "stock", "share", "dse", "cse", "brac epl", "ucb", "ipo", "dividend",
    // Banking
    "savings", "fd", "fixed deposit", "dps", "sanchay", "sanchayapatra",
    "bond", "treasury", "profit", "interest", "munafa",
    // Crypto
    "crypto", "bitcoin", "btc", "ethereum", "eth", "binance", "usdt",
    // Other investments
    "mutual fund", "investment", "portfolio", "asset", "gold", "land", "property"
  ],

  // Personal Care
  Personal_Care: [
    "salon", "parlor", "parlour", "haircut", "hair", "spa", "massage", "facial",
    "manicure", "pedicure", "grooming", "beauty", "cosmetics", "makeup", "skincare",
    "perfume", "fragrance", "lotion", "cream", "serum", "barber", "shave"
  ],

  // Family & Kids
  Family: [
    "baby", "kid", "child", "children", "school fee", "daycare", "nanny",
    "diaper", "formula", "toy", "birthday", "party", "celebration",
    "gift for", "present for", "family outing", "picnic", "vacation"
  ],

  // Donations & Charity
  Charity: [
    "donation", "dan", "charity", "zakat", "sadqa", "sadaqa", "fitra", "fitrah",
    "mosque", "masjid", "madrasa", "orphanage", "helpless", "poor", "needy",
    "relief", "flood relief", "fundraiser", "crowdfunding"
  ]
};

/**
 * Suggest a category based on the note/description text
 */
export function suggestCategory(note: string): string | null {
  if (!note || note.trim().length < 2) return null;
  
  const lowerNote = note.toLowerCase();
  
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    for (const keyword of keywords) {
      if (lowerNote.includes(keyword.toLowerCase())) {
        return category;
      }
    }
  }
  
  return null;
}

/**
 * Get all matching categories for a note (for suggestions dropdown)
 */
export function suggestCategories(note: string): string[] {
  if (!note || note.trim().length < 2) return [];
  
  const lowerNote = note.toLowerCase();
  const matches: string[] = [];
  
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    for (const keyword of keywords) {
      if (lowerNote.includes(keyword.toLowerCase())) {
        if (!matches.includes(category)) {
          matches.push(category);
        }
        break;
      }
    }
  }
  
  return matches;
}

// ==========================================
// FINANCIAL HEALTH SCORE
// ==========================================

export interface HealthMetricResult {
  score: number;
  maxScore: number;
  value: number;
  label: string;
  insufficientData?: boolean;
}

export interface HealthScoreBreakdown {
  overall: number; // 0-100, normalized across whichever metrics have data
  hasEnoughData: boolean; // false when fewer than 2 metrics could be measured
  savingsRate: HealthMetricResult;
  budgetAdherence: HealthMetricResult;
  spendingConsistency: HealthMetricResult;
  incomeStability: HealthMetricResult;
  financialCushion: HealthMetricResult;
  grade: "A" | "B" | "C" | "D" | "F";
  emoji: string;
  message: string;
}

/**
 * Outstanding money owed to other people (borrow/lend/repay/receive),
 * netted per person so an overpayment to one person can't offset debt owed
 * to a different one. Mirrors the per-person netting in components/ledger.tsx.
 */
function calculateOutstandingDebt(transactions: Transaction[]): number {
  const byPerson: Record<string, { youOwe: number; theyOwe: number }> = {};

  for (const tx of transactions) {
    if (!tx.person_id) continue;
    const entry = byPerson[tx.person_id] || { youOwe: 0, theyOwe: 0 };
    const amount = Number(tx.amount);
    switch (tx.type) {
      case "borrow": entry.youOwe += amount; break;
      case "lend": entry.theyOwe += amount; break;
      case "repay": entry.youOwe -= amount; break;
      case "receive": entry.theyOwe -= amount; break;
    }
    byPerson[tx.person_id] = entry;
  }

  return Object.values(byPerson).reduce(
    (sum, entry) => sum + Math.max(0, entry.youOwe),
    0,
  );
}

/**
 * Calculate financial health score (0-100).
 *
 * Savings rate, spending consistency, and income stability compare a
 * trailing 30-day window against the 30 days before it, rather than the
 * current calendar month against last calendar month - a strict calendar
 * comparison badly distorts the score early in the month (e.g. rent paid
 * on day 1 before salary lands looks like a spending crisis). Budget
 * adherence stays calendar-month based since budgets are inherently
 * monthly in this app. Any metric that can't be measured yet (no data in
 * the relevant window) is excluded from the overall score rather than
 * silently defaulting to a mid-range "looks fine" value.
 */
export function calculateFinancialHealth(
  transactions: Transaction[],
  currentBalance: number,
  budgets?: { category: string; amount: number }[],
): HealthScoreBreakdown {
  const now = new Date();

  // Rolling windows for flow-based metrics.
  const periodStart = subDays(now, 30);
  const priorPeriodStart = subDays(now, 60);
  const periodTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= periodStart && d <= now;
  });
  const priorPeriodTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= priorPeriodStart && d < periodStart;
  });

  const sumType = (rows: Transaction[], type: string) =>
    rows.filter((tx) => tx.type === type).reduce((sum, tx) => sum + Number(tx.amount), 0);

  const periodIncome = sumType(periodTx, "income");
  const periodExpense = sumType(periodTx, "expense");
  const priorPeriodIncome = sumType(priorPeriodTx, "income");
  const priorPeriodExpense = sumType(priorPeriodTx, "expense");

  // Calendar month, used only for budget adherence (budgets are monthly).
  const thisMonthStart = startOfMonth(now);
  const thisMonthEnd = endOfMonth(now);
  const thisMonthTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= thisMonthStart && d <= thisMonthEnd;
  });
  const thisMonthExpense = sumType(thisMonthTx, "expense");

  // 1. Savings Rate Score (0-25 points)
  const hasFlowData = periodIncome > 0 || periodExpense > 0;
  const savingsRateValue = periodIncome > 0
    ? ((periodIncome - periodExpense) / periodIncome) * 100
    : 0;

  let savingsScore = 0;
  let savingsLabel = "Not enough data";

  if (!hasFlowData) {
    // leave as insufficient data
  } else if (savingsRateValue >= 30) { savingsScore = 25; savingsLabel = "Excellent"; }
  else if (savingsRateValue >= 20) { savingsScore = 21; savingsLabel = "Great"; }
  else if (savingsRateValue >= 10) { savingsScore = 17; savingsLabel = "Good"; }
  else if (savingsRateValue >= 0) { savingsScore = 12; savingsLabel = "Fair"; }
  else { savingsScore = 4; savingsLabel = "Needs attention"; }

  // 2. Budget Adherence Score (0-20 points)
  let budgetScore = 12; // Default if no budgets (60% of max, same proportion as before)
  let budgetValue = 0;
  let budgetLabel = "No budgets set";

  if (budgets && budgets.length > 0) {
    const categorySpending: Record<string, number> = {};
    thisMonthTx
      .filter((tx) => tx.type === "expense")
      .forEach((tx) => {
        const cat = tx.category || "Uncategorized";
        categorySpending[cat] = (categorySpending[cat] || 0) + Number(tx.amount);
      });

    let adherenceTotal = 0;
    let budgetCount = 0;

    for (const budget of budgets) {
      const spent = categorySpending[budget.category] || 0;
      const adherence = budget.amount > 0
        ? Math.min(100, (1 - (spent - budget.amount) / budget.amount) * 100)
        : 100;
      adherenceTotal += Math.max(0, adherence);
      budgetCount++;
    }

    budgetValue = budgetCount > 0 ? adherenceTotal / budgetCount : 100;
    budgetScore = Math.round((budgetValue / 100) * 20);

    if (budgetValue >= 90) budgetLabel = "Excellent";
    else if (budgetValue >= 70) budgetLabel = "Good";
    else if (budgetValue >= 50) budgetLabel = "Fair";
    else budgetLabel = "Over budget";

    // Per-category adherence can look "Excellent" while overall spending
    // still blows past the total budget through unbudgeted categories -
    // dock points when that happens instead of missing it entirely.
    const totalBudgetCap = budgets.reduce((sum, b) => sum + b.amount, 0);
    if (totalBudgetCap > 0 && thisMonthExpense > totalBudgetCap * 1.2) {
      budgetScore = Math.round(budgetScore * 0.6);
      budgetLabel = "Overspending outside budgets";
    }
  }

  // 3. Spending Consistency Score (0-20 points)
  const hasConsistencyData = priorPeriodExpense > 0;
  const expenseChange = hasConsistencyData
    ? Math.abs((periodExpense - priorPeriodExpense) / priorPeriodExpense) * 100
    : 0;

  let consistencyScore = 0;
  let consistencyLabel = "Not enough data";

  if (!hasConsistencyData) {
    // leave as insufficient data
  } else if (expenseChange <= 10) { consistencyScore = 20; consistencyLabel = "Very stable"; }
  else if (expenseChange <= 20) { consistencyScore = 16; consistencyLabel = "Stable"; }
  else if (expenseChange <= 30) { consistencyScore = 12; consistencyLabel = "Moderate"; }
  else if (expenseChange <= 50) { consistencyScore = 8; consistencyLabel = "Variable"; }
  else { consistencyScore = 4; consistencyLabel = "Volatile"; }

  // 4. Income Stability Score (0-15 points)
  const hasIncomeStabilityData = priorPeriodIncome > 0;
  const incomeChange = hasIncomeStabilityData
    ? Math.abs((periodIncome - priorPeriodIncome) / priorPeriodIncome) * 100
    : 0;

  let incomeScore = 0;
  let incomeLabel = "Not enough data";

  if (!hasIncomeStabilityData) {
    // leave as insufficient data
  } else if (incomeChange <= 5) { incomeScore = 15; incomeLabel = "Very stable"; }
  else if (incomeChange <= 15) { incomeScore = 11; incomeLabel = "Stable"; }
  else if (incomeChange <= 30) { incomeScore = 7; incomeLabel = "Moderate"; }
  else { incomeScore = 4; incomeLabel = "Variable"; }

  // 5. Financial Cushion Score (0-20 points) - months of expenses covered
  // by current balance minus outstanding debt owed to other people.
  const outstandingDebt = calculateOutstandingDebt(transactions);
  const netLiquidPosition = currentBalance - outstandingDebt;
  const avgDailyExpense = periodExpense / 30;

  let cushionScore: number;
  let cushionLabel: string;
  let cushionDays: number;

  if (avgDailyExpense <= 0) {
    cushionDays = netLiquidPosition > 0 ? Infinity : 0;
    cushionScore = netLiquidPosition > 0 ? 20 : 4;
    cushionLabel = netLiquidPosition > 0 ? "Excellent" : "Needs attention";
  } else {
    cushionDays = netLiquidPosition / avgDailyExpense;
    if (netLiquidPosition <= 0) { cushionScore = 0; cushionLabel = "In the red"; }
    else if (cushionDays >= 90) { cushionScore = 20; cushionLabel = "Excellent"; }
    else if (cushionDays >= 60) { cushionScore = 16; cushionLabel = "Great"; }
    else if (cushionDays >= 30) { cushionScore = 12; cushionLabel = "Good"; }
    else if (cushionDays >= 14) { cushionScore = 8; cushionLabel = "Fair"; }
    else { cushionScore = 4; cushionLabel = "Needs attention"; }
  }

  // Normalize the overall score across only the metrics that had enough
  // data to measure, so a new account isn't penalized (or flattered) by
  // metrics that are really just "unknown".
  const metrics: { score: number; max: number; insufficient: boolean }[] = [
    { score: savingsScore, max: 25, insufficient: !hasFlowData },
    { score: budgetScore, max: 20, insufficient: false },
    { score: consistencyScore, max: 20, insufficient: !hasConsistencyData },
    { score: incomeScore, max: 15, insufficient: !hasIncomeStabilityData },
    { score: cushionScore, max: 20, insufficient: false },
  ];
  const available = metrics.filter((m) => !m.insufficient);
  const availableMax = available.reduce((sum, m) => sum + m.max, 0);
  const overall = availableMax > 0
    ? Math.round((available.reduce((sum, m) => sum + m.score, 0) / availableMax) * 100)
    : 0;
  // Budget adherence (defaults when no budgets are set) and financial
  // cushion (computable from balance alone, even at ৳0) can both look
  // "available" without a single real transaction ever happening - require
  // at least one metric actually derived from transaction history too, or
  // a brand-new account gets a confident-looking grade from nothing.
  const hasRealFlowData = hasFlowData || hasConsistencyData || hasIncomeStabilityData;
  const hasEnoughData = hasRealFlowData && available.length >= 2;

  // Determine grade
  let grade: "A" | "B" | "C" | "D" | "F";
  let emoji: string;
  let message: string;

  if (!hasEnoughData) {
    grade = "F"; emoji = "🌱"; message = "Add a few weeks of transactions to unlock a meaningful score.";
  } else if (overall >= 85) {
    grade = "A"; emoji = "🌟"; message = "Outstanding! You're a financial superstar!";
  } else if (overall >= 70) {
    grade = "B"; emoji = "💪"; message = "Great job! Keep up the good habits!";
  } else if (overall >= 55) {
    grade = "C"; emoji = "👍"; message = "You're doing okay. Room for improvement!";
  } else if (overall >= 40) {
    grade = "D"; emoji = "⚠️"; message = "Consider reviewing your spending habits.";
  } else {
    grade = "F"; emoji = "🚨"; message = "Time to take control of your finances!";
  }

  return {
    overall,
    hasEnoughData,
    savingsRate: { score: savingsScore, maxScore: 25, value: savingsRateValue, label: savingsLabel, insufficientData: !hasFlowData },
    budgetAdherence: { score: budgetScore, maxScore: 20, value: budgetValue, label: budgetLabel },
    spendingConsistency: { score: consistencyScore, maxScore: 20, value: 100 - expenseChange, label: consistencyLabel, insufficientData: !hasConsistencyData },
    incomeStability: { score: incomeScore, maxScore: 15, value: 100 - incomeChange, label: incomeLabel, insufficientData: !hasIncomeStabilityData },
    financialCushion: { score: cushionScore, maxScore: 20, value: cushionDays === Infinity ? 999 : cushionDays, label: cushionLabel },
    grade,
    emoji,
    message,
  };
}

// ==========================================
// AI INSIGHTS GENERATOR
// ==========================================

export interface Insight {
  id: string;
  type: "positive" | "warning" | "info" | "tip";
  icon: string;
  title: string;
  description: string;
  priority: number; // Higher = more important
}

/**
 * Generate smart insights based on transaction data
 */
export function generateInsights(transactions: Transaction[]): Insight[] {
  const insights: Insight[] = [];
  const now = new Date();
  const thisMonthStart = startOfMonth(now);
  const thisMonthEnd = endOfMonth(now);
  const lastMonthStart = startOfMonth(subMonths(now, 1));
  const lastMonthEnd = endOfMonth(subMonths(now, 1));
  
  const thisMonthTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= thisMonthStart && d <= thisMonthEnd;
  });
  
  const lastMonthTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= lastMonthStart && d <= lastMonthEnd;
  });
  
  // Calculate summaries
  const thisMonthIncome = thisMonthTx
    .filter((tx) => tx.type === "income")
    .reduce((sum, tx) => sum + Number(tx.amount), 0);
  
  const thisMonthExpense = thisMonthTx
    .filter((tx) => tx.type === "expense")
    .reduce((sum, tx) => sum + Number(tx.amount), 0);
  
  const lastMonthIncome = lastMonthTx
    .filter((tx) => tx.type === "income")
    .reduce((sum, tx) => sum + Number(tx.amount), 0);
  
  const lastMonthExpense = lastMonthTx
    .filter((tx) => tx.type === "expense")
    .reduce((sum, tx) => sum + Number(tx.amount), 0);
  
  // Get category breakdown for this month
  const categorySpending: Record<string, number> = {};
  thisMonthTx
    .filter((tx) => tx.type === "expense")
    .forEach((tx) => {
      const cat = tx.category || "Uncategorized";
      categorySpending[cat] = (categorySpending[cat] || 0) + Number(tx.amount);
    });
  
  const sortedCategories = Object.entries(categorySpending)
    .sort(([, a], [, b]) => b - a);
  
  // Last month category spending
  const lastMonthCategorySpending: Record<string, number> = {};
  lastMonthTx
    .filter((tx) => tx.type === "expense")
    .forEach((tx) => {
      const cat = tx.category || "Uncategorized";
      lastMonthCategorySpending[cat] = (lastMonthCategorySpending[cat] || 0) + Number(tx.amount);
    });
  
  // ===== INSIGHT 1: Top Spending Category =====
  if (sortedCategories.length > 0) {
    const [topCategory, topAmount] = sortedCategories[0];
    const percentage = thisMonthExpense > 0 
      ? Math.round((topAmount / thisMonthExpense) * 100) 
      : 0;
    
    insights.push({
      id: "top-category",
      type: "info",
      icon: "📊",
      title: `Top spending: ${topCategory}`,
      description: `${percentage}% of your expenses (৳${topAmount.toLocaleString()})`,
      priority: 8,
    });
  }
  
  // ===== INSIGHT 2: Savings Rate =====
  if (thisMonthIncome > 0) {
    const savingsRate = Math.round(((thisMonthIncome - thisMonthExpense) / thisMonthIncome) * 100);
    
    if (savingsRate >= 20) {
      insights.push({
        id: "savings-positive",
        type: "positive",
        icon: "🎉",
        title: `Saving ${savingsRate}% of income!`,
        description: "Great job! You're on track for your financial goals.",
        priority: 9,
      });
    } else if (savingsRate < 0) {
      insights.push({
        id: "savings-negative",
        type: "warning",
        icon: "⚠️",
        title: "Spending more than earning",
        description: `You've spent ৳${Math.abs(thisMonthIncome - thisMonthExpense).toLocaleString()} more than your income.`,
        priority: 10,
      });
    }
  }
  
  // ===== INSIGHT 3: Month-over-Month Change =====
  if (lastMonthExpense > 0) {
    const expenseChange = ((thisMonthExpense - lastMonthExpense) / lastMonthExpense) * 100;
    
    if (expenseChange > 20) {
      insights.push({
        id: "expense-increase",
        type: "warning",
        icon: "📈",
        title: `Spending up ${Math.round(expenseChange)}%`,
        description: `You've spent ৳${(thisMonthExpense - lastMonthExpense).toLocaleString()} more than last month.`,
        priority: 7,
      });
    } else if (expenseChange < -20) {
      insights.push({
        id: "expense-decrease",
        type: "positive",
        icon: "📉",
        title: `Spending down ${Math.round(Math.abs(expenseChange))}%`,
        description: `You've saved ৳${(lastMonthExpense - thisMonthExpense).toLocaleString()} compared to last month!`,
        priority: 7,
      });
    }
  }
  
  // ===== INSIGHT 4: Category Increase Warning =====
  for (const [category, amount] of sortedCategories.slice(0, 3)) {
    const lastAmount = lastMonthCategorySpending[category] || 0;
    if (lastAmount > 0) {
      const change = ((amount - lastAmount) / lastAmount) * 100;
      if (change > 50) {
        insights.push({
          id: `category-spike-${category}`,
          type: "warning",
          icon: "🔺",
          title: `${category} spending ↑ ${Math.round(change)}%`,
          description: `Increased from ৳${lastAmount.toLocaleString()} to ৳${amount.toLocaleString()}`,
          priority: 6,
        });
        break; // Only show one category spike
      }
    }
  }
  
  // ===== INSIGHT 5: Daily Average =====
  const daysInMonth = now.getDate();
  const dailyAverage = thisMonthExpense / daysInMonth;
  const projectedMonthEnd = dailyAverage * new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  
  if (projectedMonthEnd > lastMonthExpense * 1.2 && lastMonthExpense > 0) {
    insights.push({
      id: "projected-overspend",
      type: "tip",
      icon: "💡",
      title: "Projected to exceed last month",
      description: `At this rate, you'll spend ~৳${Math.round(projectedMonthEnd).toLocaleString()} by month end.`,
      priority: 5,
    });
  }
  
  // ===== INSIGHT 6: No transactions yet =====
  if (thisMonthTx.length === 0) {
    insights.push({
      id: "no-transactions",
      type: "info",
      icon: "📝",
      title: "Start tracking this month",
      description: "Add your first transaction to see insights!",
      priority: 10,
    });
  }
  
  // ===== INSIGHT 7: Positive transactions streak =====
  const last7Days = transactions.filter((tx) => {
    const d = new Date(tx.date);
    const sevenDaysAgo = new Date(now);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    return d >= sevenDaysAgo;
  });
  
  if (last7Days.length >= 7) {
    insights.push({
      id: "tracking-streak",
      type: "positive",
      icon: "🔥",
      title: "Great tracking habit!",
      description: `${last7Days.length} transactions logged in the past week.`,
      priority: 4,
    });
  }
  
  // ===== INSIGHT 8: Investment Portfolio Summary =====
  const totalInvested = transactions
    .filter((tx) => tx.type === "invest")
    .reduce((sum, tx) => sum + Number(tx.amount), 0);

  const totalReturned = transactions
    .filter((tx) => tx.type === "invest_return")
    .reduce((sum, tx) => sum + Number(tx.amount), 0);

  if (totalInvested > 0) {
    const netPL = totalReturned - totalInvested;
    const roi = ((netPL / totalInvested) * 100).toFixed(1);
    const isProfit = netPL >= 0;

    insights.push({
      id: "investment-portfolio",
      type: isProfit ? "positive" : "info",
      icon: "💼",
      title: "Investment Portfolio Summary",
      description: isProfit 
        ? `Your investments have yielded a net profit of ৳${netPL.toLocaleString()} (ROI: ${roi}%). Great performance!` 
        : `Your portfolio shows a temporary net loss of ৳${Math.abs(netPL).toLocaleString()} (ROI: ${roi}%). Patience and diversified holdings pay off in the long run.`,
      priority: 9.5, // High priority so it appears at or near the top
    });
  }
  
  // Sort by priority (descending)
  return insights.sort((a, b) => b.priority - a.priority).slice(0, 4);
}

// ==========================================
// CASH FLOW FORECAST
// ==========================================

export type CashFlowStatus =
  | "insufficient-data"
  | "growing"
  | "stable"
  | "declining"
  | "critical";

export interface CashFlowForecast {
  status: CashFlowStatus;
  currentBalance: number;
  avgDailyNetChange: number;
  daysOfHistory: number;
  projectedDate: string | null;
  daysRemaining: number | null;
  message: string;
}

const FORECAST_WINDOW_DAYS = 30;
const FORECAST_MIN_HISTORY_DAYS = 7;

/**
 * Projects when the user's total balance will run out (or how it'll grow)
 * based on the trailing net daily cash flow across all their own accounts.
 * Transfers between own accounts net to zero automatically since both the
 * credit and debit side are included in the same sum.
 */
export function calculateCashFlowForecast(
  transactions: Transaction[],
  currentBalance: number,
): CashFlowForecast {
  const now = new Date();
  const windowStart = new Date(now);
  windowStart.setDate(windowStart.getDate() - FORECAST_WINDOW_DAYS);

  const txTimes = transactions.map((tx) => new Date(tx.date).getTime());
  const earliestTxTime = txTimes.length > 0 ? Math.min(...txTimes) : now.getTime();
  const daysOfHistory = Math.min(
    FORECAST_WINDOW_DAYS,
    Math.max(0, Math.floor((now.getTime() - earliestTxTime) / (1000 * 60 * 60 * 24))),
  );

  if (daysOfHistory < FORECAST_MIN_HISTORY_DAYS) {
    return {
      status: "insufficient-data",
      currentBalance,
      avgDailyNetChange: 0,
      daysOfHistory,
      projectedDate: null,
      daysRemaining: null,
      message:
        "Keep logging transactions - we need at least a week of history to forecast your cash flow.",
    };
  }

  const windowTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= windowStart && d <= now;
  });

  const netChange = windowTx.reduce((sum, tx) => {
    const amount = Number(tx.amount);
    if (!Number.isFinite(amount)) return sum;
    let delta = 0;
    if (tx.to_account_id) delta += amount;
    if (tx.from_account_id) delta -= amount;
    return sum + delta;
  }, 0);

  const avgDailyNetChange = netChange / daysOfHistory;

  if (avgDailyNetChange >= 0) {
    const projectedGrowth = avgDailyNetChange * 30;
    return {
      status: avgDailyNetChange === 0 ? "stable" : "growing",
      currentBalance,
      avgDailyNetChange,
      daysOfHistory,
      projectedDate: null,
      daysRemaining: null,
      message:
        avgDailyNetChange === 0
          ? "Your balance has held steady recently - income and spending are roughly matched."
          : `At this pace, your balance is on track to grow by ~৳${Math.round(projectedGrowth).toLocaleString()} over the next 30 days.`,
    };
  }

  const burnRate = -avgDailyNetChange;
  if (currentBalance <= 0) {
    return {
      status: "critical",
      currentBalance,
      avgDailyNetChange,
      daysOfHistory,
      projectedDate: null,
      daysRemaining: 0,
      message:
        "Your balance is already at or below zero, and recent spending is outpacing income.",
    };
  }

  const daysRemaining = Math.floor(currentBalance / burnRate);
  const projectedDate = new Date(now);
  projectedDate.setDate(projectedDate.getDate() + daysRemaining);

  if (daysRemaining > 180) {
    return {
      status: "declining",
      currentBalance,
      avgDailyNetChange,
      daysOfHistory,
      projectedDate: projectedDate.toISOString(),
      daysRemaining,
      message:
        "Spending is outpacing income slightly, but at this rate you have more than 6 months of runway - worth watching, not urgent.",
    };
  }

  return {
    status: daysRemaining <= 14 ? "critical" : "declining",
    currentBalance,
    avgDailyNetChange,
    daysOfHistory,
    projectedDate: projectedDate.toISOString(),
    daysRemaining,
    message: `At this rate, you'll run low by ${format(projectedDate, "MMM d")} (about ${daysRemaining} day${daysRemaining === 1 ? "" : "s"}) if nothing changes.`,
  };
}

// ==========================================
// ANOMALY DETECTION
// ==========================================

export interface Anomaly {
  transaction: Transaction;
  reason: string;
  severity: "low" | "medium" | "high";
}

/**
 * Detect unusual transactions
 */
export function detectAnomalies(transactions: Transaction[]): Anomaly[] {
  const anomalies: Anomaly[] = [];
  
  // Get last 3 months of transactions
  const threeMonthsAgo = subMonths(new Date(), 3);
  const recentTx = transactions.filter((tx) => new Date(tx.date) >= threeMonthsAgo);
  
  // Calculate category averages
  const categoryStats: Record<string, { total: number; count: number; avg: number }> = {};
  
  recentTx
    .filter((tx) => tx.type === "expense")
    .forEach((tx) => {
      const cat = tx.category || "Uncategorized";
      if (!categoryStats[cat]) {
        categoryStats[cat] = { total: 0, count: 0, avg: 0 };
      }
      categoryStats[cat].total += Number(tx.amount);
      categoryStats[cat].count += 1;
    });
  
  for (const cat of Object.keys(categoryStats)) {
    categoryStats[cat].avg = categoryStats[cat].total / categoryStats[cat].count;
  }
  
  // Check this month's transactions for anomalies
  const thisMonth = startOfMonth(new Date());
  const thisMonthTx = transactions.filter((tx) => new Date(tx.date) >= thisMonth);
  
  for (const tx of thisMonthTx) {
    if (tx.type !== "expense") continue;
    
    const cat = tx.category || "Uncategorized";
    const stats = categoryStats[cat];
    
    if (stats && stats.count >= 3) {
      const amount = Number(tx.amount);
      
      if (amount > stats.avg * 3) {
        anomalies.push({
          transaction: tx,
          reason: `3x higher than your ${cat} average (৳${Math.round(stats.avg).toLocaleString()})`,
          severity: "high",
        });
      } else if (amount > stats.avg * 2) {
        anomalies.push({
          transaction: tx,
          reason: `2x higher than your ${cat} average`,
          severity: "medium",
        });
      }
    }
  }
  
  return anomalies.slice(0, 3); // Return top 3 anomalies
}
