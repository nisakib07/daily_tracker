"use client";

import type { Transaction } from "@/lib/types";
import { startOfMonth, endOfMonth, subMonths, format } from "date-fns";

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

export interface HealthScoreBreakdown {
  overall: number; // 0-100
  savingsRate: { score: number; value: number; label: string };
  budgetAdherence: { score: number; value: number; label: string };
  spendingConsistency: { score: number; value: number; label: string };
  incomeStability: { score: number; value: number; label: string };
  grade: "A" | "B" | "C" | "D" | "F";
  emoji: string;
  message: string;
}

/**
 * Calculate financial health score (0-100)
 */
export function calculateFinancialHealth(
  transactions: Transaction[],
  budgets?: { category: string; amount: number }[]
): HealthScoreBreakdown {
  const now = new Date();
  const thisMonthStart = startOfMonth(now);
  const thisMonthEnd = endOfMonth(now);
  const lastMonthStart = startOfMonth(subMonths(now, 1));
  const lastMonthEnd = endOfMonth(subMonths(now, 1));
  
  // Get transactions for this month and last month
  const thisMonthTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= thisMonthStart && d <= thisMonthEnd;
  });
  
  const lastMonthTx = transactions.filter((tx) => {
    const d = new Date(tx.date);
    return d >= lastMonthStart && d <= lastMonthEnd;
  });
  
  // Calculate income and expenses
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
  
  // 1. Savings Rate Score (0-30 points)
  const savingsRateValue = thisMonthIncome > 0 
    ? ((thisMonthIncome - thisMonthExpense) / thisMonthIncome) * 100 
    : 0;
  
  let savingsScore = 0;
  let savingsLabel = "";
  
  if (savingsRateValue >= 30) { savingsScore = 30; savingsLabel = "Excellent"; }
  else if (savingsRateValue >= 20) { savingsScore = 25; savingsLabel = "Great"; }
  else if (savingsRateValue >= 10) { savingsScore = 20; savingsLabel = "Good"; }
  else if (savingsRateValue >= 0) { savingsScore = 15; savingsLabel = "Fair"; }
  else { savingsScore = 5; savingsLabel = "Needs attention"; }
  
  // 2. Budget Adherence Score (0-25 points)
  let budgetScore = 15; // Default if no budgets
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
    budgetScore = Math.round((budgetValue / 100) * 25);
    
    if (budgetValue >= 90) budgetLabel = "Excellent";
    else if (budgetValue >= 70) budgetLabel = "Good";
    else if (budgetValue >= 50) budgetLabel = "Fair";
    else budgetLabel = "Over budget";
  }
  
  // 3. Spending Consistency Score (0-25 points)
  const expenseChange = lastMonthExpense > 0
    ? Math.abs((thisMonthExpense - lastMonthExpense) / lastMonthExpense) * 100
    : 0;
  
  let consistencyScore = 0;
  let consistencyLabel = "";
  
  if (expenseChange <= 10) { consistencyScore = 25; consistencyLabel = "Very stable"; }
  else if (expenseChange <= 20) { consistencyScore = 20; consistencyLabel = "Stable"; }
  else if (expenseChange <= 30) { consistencyScore = 15; consistencyLabel = "Moderate"; }
  else if (expenseChange <= 50) { consistencyScore = 10; consistencyLabel = "Variable"; }
  else { consistencyScore = 5; consistencyLabel = "Volatile"; }
  
  // 4. Income Stability Score (0-20 points)
  const incomeChange = lastMonthIncome > 0
    ? Math.abs((thisMonthIncome - lastMonthIncome) / lastMonthIncome) * 100
    : 0;
  
  let incomeScore = 0;
  let incomeLabel = "";
  
  if (incomeChange <= 5) { incomeScore = 20; incomeLabel = "Very stable"; }
  else if (incomeChange <= 15) { incomeScore = 15; incomeLabel = "Stable"; }
  else if (incomeChange <= 30) { incomeScore = 10; incomeLabel = "Moderate"; }
  else { incomeScore = 5; incomeLabel = "Variable"; }
  
  // Calculate overall score
  const overall = savingsScore + budgetScore + consistencyScore + incomeScore;
  
  // Determine grade
  let grade: "A" | "B" | "C" | "D" | "F";
  let emoji: string;
  let message: string;
  
  if (overall >= 85) {
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
    savingsRate: { score: savingsScore, value: savingsRateValue, label: savingsLabel },
    budgetAdherence: { score: budgetScore, value: budgetValue, label: budgetLabel },
    spendingConsistency: { score: consistencyScore, value: 100 - expenseChange, label: consistencyLabel },
    incomeStability: { score: incomeScore, value: 100 - incomeChange, label: incomeLabel },
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
  
  // Sort by priority (descending)
  return insights.sort((a, b) => b.priority - a.priority).slice(0, 4);
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
