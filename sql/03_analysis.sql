--======================================================================
-- Analysis
--======================================================================


--------- 1. Funnel Performance Overview ---------

-- 1.1 Session-based Funnel Drop-Off and Overall CVR
WITH stage_counts AS (
  SELECT
    stage_sequence,
    stage_label,
    COUNT(DISTINCT session_id) AS sessions,
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  GROUP BY stage_sequence, stage_label
),

funnel_calc_session AS (
  SELECT
    stage_sequence,
    stage_label,
    sessions,
    LAG(sessions, 1) OVER (ORDER BY stage_sequence)      AS prev_stage_sessions,
    FIRST_VALUE(sessions) OVER (ORDER BY stage_sequence) AS awareness_sessions
  FROM stage_counts
)

SELECT
    stage_sequence,
    stage_label,
    sessions,
    ROUND((1 - SAFE_DIVIDE(sessions, prev_stage_sessions)) * 100, 1)  AS dropoff_rate_pct,
    ROUND(SAFE_DIVIDE(sessions, awareness_sessions)  * 100, 1)        AS session_cvr_from_top
FROM funnel_calc_session
ORDER BY stage_sequence ASC;


-- 1.2 User-based Funnel Drop-Off and Overall CVR
WITH stage_counts AS (
  SELECT
    stage_sequence,
    stage_label,
    COUNT(DISTINCT user_id) AS users
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  GROUP BY stage_sequence, stage_label
),

funnel_calc_user AS (
  SELECT
    stage_sequence,
    stage_label,
    users,
    LAG(users, 1) OVER (ORDER BY stage_sequence)      AS prev_stage_users,
    FIRST_VALUE(users) OVER (ORDER BY stage_sequence) AS awareness_users
  FROM stage_counts
)

SELECT
    stage_sequence,
    stage_label,
    users,
    ROUND((1 - SAFE_DIVIDE(users, prev_stage_users)) * 100, 1)  AS dropoff_rate_pct,
    ROUND(SAFE_DIVIDE(users, awareness_users)  * 100, 1)        AS true_cvr_from_top
FROM funnel_calc_user
ORDER BY stage_sequence ASC;

--  Revenue Summary
SELECT
  COUNT(DISTINCT session_id)                    AS purchase_sessions,
  ROUND(SUM(revenue), 2)                        AS total_revenue,
  ROUND(AVG(revenue), 0)                        AS aov,
  ROUND(MIN(revenue), 2)                        AS min_order_value,
  ROUND(MAX(revenue), 2)                        AS max_order_value
FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
WHERE stage_sequence = 6;



--------- 2. Channel & Campaign Effectiveness ---------

-- 2.1 Traffic Source Performance and ROAS
WITH channel_budget AS (
  SELECT
    channel                    AS traffic_source,
    ROUND(SUM(budget), 2)      AS total_budget
  FROM `nn-marketing-funnel-analysis.web_events.dim_campaigns`
  WHERE campaign_name != 'eu_brand_awareness'  -- no events in Q1
  GROUP BY channel
)

SELECT
  f.traffic_source,
  COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN session_id END)      AS awareness_sessions,
  COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN session_id END)      AS purchase_sessions,
  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN session_id END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN session_id END)
  ) * 100, 1)                                                            AS session_cvr_pct,
  ROUND(SUM(CASE WHEN stage_sequence = 6 THEN revenue END), 2)          AS revenue,
  ROUND(AVG(CASE WHEN stage_sequence = 6 THEN revenue END), 0)          AS aov,
  cb.total_budget,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN stage_sequence = 6 THEN revenue END),
    cb.total_budget
  ), 2)                                                                  AS roas

FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base` AS f
LEFT JOIN channel_budget AS cb 
       ON f.traffic_source = cb.traffic_source
GROUP BY f.traffic_source, cb.total_budget
ORDER BY session_cvr_pct DESC;


-- 2.2 Campaign Performance Summary
WITH max_stage_session AS (
  SELECT 
    session_id,
    MAX(stage_sequence) AS max_stage
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  GROUP BY session_id
)

SELECT
  f.campaign_name,
  f.channel,
  -- cvr and early exit rate
  COUNT(DISTINCT CASE WHEN f.stage_sequence = 1 THEN f.session_id END)   AS awareness_sessions,
  COUNT(DISTINCT CASE WHEN f.stage_sequence = 6 THEN f.session_id END)   AS purchase_sessions,

  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN f.stage_sequence = 6 THEN f.session_id END),
    COUNT(DISTINCT CASE WHEN f.stage_sequence = 1 THEN f.session_id END)
  ) * 100, 1)                                                            AS session_cvr_pct,

  COUNT(DISTINCT 
    CASE WHEN m.max_stage = 1 THEN f.session_id END)                     AS awareness_only_sessions,
  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN m.max_stage = 1 THEN f.session_id END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN f.session_id END)
  ) * 100, 1)                                                            AS early_exit_rate_pct,

  -- roas
  MAX(f.budget)                                                          AS budget,
  ROUND(SUM(
    CASE WHEN f.stage_sequence = 6 THEN f.revenue ELSE 0 END)
    , 2)                                                                 AS revenue,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN f.stage_sequence = 6 THEN f.revenue ELSE 0 END),
    MAX(f.budget)
  ), 2)                                                                  AS roas

FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base` AS f
LEFT JOIN max_stage_session AS m
       ON f.session_id = m.session_id
WHERE f.traffic_source NOT IN ('direct', 'organic')
  AND f.campaign_name IS NOT NULL
GROUP BY f.campaign_name, f.channel
ORDER BY roas DESC;


--- 2.3 Overall Budget vs. Revenue
WITH campaign_budget AS (
  SELECT
    campaign_name,
    MAX(budget) AS budget
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  GROUP BY campaign_name
)

SELECT
  (SELECT SUM(budget) FROM campaign_budget)   AS total_budget,
  ROUND(SUM(revenue), 2)                      AS revenue,
  ROUND(SAFE_DIVIDE(
    ROUND(SUM(revenue), 2),
    (SELECT SUM(budget) FROM campaign_budget)
  ), 2)                                       AS roas
FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
WHERE traffic_source NOT IN ('direct', 'organic')
  AND campaign_name IS NOT NULL ;



--------- 3. Regional Funnel Breakdown ---------

-- 3.1 Regional Performance

-- 3.1.1 Funnel Summary
SELECT
  region,
  COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN session_id END)      AS awareness_sessions,
  COUNT(DISTINCT CASE WHEN stage_sequence = 6  THEN session_id END)      AS purchase_sessions,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN session_id END),
                    COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN session_id END)
                    )  * 100, 1)                                         AS session_cvr_pct,
  ROUND(SUM(CASE WHEN stage_sequence = 6 THEN revenue END), 2)           AS revenue,
  ROUND(AVG(CASE WHEN stage_sequence = 6 THEN revenue END), 0)           AS aov,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN stage_sequence = 6 THEN revenue END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN session_id END)
  ), 2)                                                                  AS revenue_per_session
FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
GROUP BY region
ORDER BY session_cvr_pct DESC;

-- 3.1.2 Funnel Breakdown
WITH stage_counts AS (
  SELECT
    region,
    stage_sequence,
    stage_label,
    COUNT(DISTINCT session_id ) AS sessions
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  GROUP BY region, stage_sequence, stage_label
),

funnel_calc AS (
  SELECT
    region,
    stage_sequence,
    stage_label,
    sessions,
    LAG(sessions, 1) OVER (
      PARTITION BY region
      ORDER BY stage_sequence)      AS prev_stage_sessions
  FROM stage_counts
),

dropoff AS (
  SELECT
    stage_sequence,
    CASE stage_sequence
      WHEN 2 THEN 'Awareness → Product'
      WHEN 3 THEN 'Product → Cart'
      WHEN 4 THEN 'Cart → Checkout'
      WHEN 5 THEN 'Checkout → Payment'
      WHEN 6 THEN 'Payment → Purchase'
      END AS stage_transition,
    region,
    ROUND((1 - SAFE_DIVIDE(sessions, prev_stage_sessions)) * 100, 1) AS dropoff_rate_pct
  FROM funnel_calc
)

SELECT
  stage_transition,
  MAX(CASE WHEN region = 'APAC'  THEN dropoff_rate_pct END)   AS APAC,
  MAX(CASE WHEN region = 'EMEA'  THEN dropoff_rate_pct END)   AS EMEA,
  MAX(CASE WHEN region = 'LATAM' THEN dropoff_rate_pct END)   AS LATAM,
  MAX(CASE WHEN region = 'NA'    THEN dropoff_rate_pct END)   AS NA,
FROM dropoff
WHERE stage_sequence != 1
GROUP BY stage_sequence, stage_transition
ORDER BY stage_sequence;



-- 3.2 Country Performance

-- 3.2.1 Funnel Summary by Country
SELECT
  region,
  country_name,
  COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN session_id END)      AS awareness_sessions,
  COUNT(DISTINCT CASE WHEN stage_sequence = 6  THEN session_id END)      AS purchase_sessions,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN session_id END),
                    COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN session_id END)
                    )  * 100, 1)                                         AS session_cvr_pct,
  ROUND(SUM(CASE WHEN stage_sequence = 6 THEN revenue END), 2)           AS revenue,
  ROUND(AVG(CASE WHEN stage_sequence = 6 THEN revenue END), 0)           AS aov,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN stage_sequence = 6 THEN revenue END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN session_id END)
  ), 2)                                                                  AS revenue_per_session
FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
GROUP BY region, country_name
ORDER BY region, session_cvr_pct DESC;

-- 3.2.2 Funnel Breakdown by Country (NA region focus)
WITH stage_counts AS (
  SELECT
    country_name,
    stage_sequence,
    stage_label,
    COUNT(DISTINCT session_id ) AS sessions
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  WHERE region = 'NA'
  GROUP BY country_name, stage_sequence, stage_label
),

funnel_calc AS (
  SELECT
    country_name,
    stage_sequence,
    stage_label,
    sessions,
    LAG(sessions, 1) OVER (
      PARTITION BY country_name
      ORDER BY stage_sequence)      AS prev_stage_sessions
  FROM stage_counts
),

dropoff AS (
  SELECT
    stage_sequence,
    CASE stage_sequence
      WHEN 2 THEN 'Awareness → Product'
      WHEN 3 THEN 'Product → Cart'
      WHEN 4 THEN 'Cart → Checkout'
      WHEN 5 THEN 'Checkout → Payment'
      WHEN 6 THEN 'Payment → Purchase'
      END AS stage_transition,
    country_name,
    ROUND((1 - SAFE_DIVIDE(sessions, prev_stage_sessions)) * 100, 1) AS dropoff_rate_pct
  FROM funnel_calc
)

SELECT
  stage_transition,
  MAX(CASE WHEN country_name = 'Canada'    THEN dropoff_rate_pct END)               AS Canada,
  MAX(CASE WHEN country_name = 'United States of America'
                    THEN dropoff_rate_pct END)                                      AS USA
FROM dropoff
WHERE stage_sequence != 1
GROUP BY stage_sequence, stage_transition
ORDER BY stage_sequence;



-- 3.3 Traffic Source Performance by Region
SELECT
  region,
  traffic_source,
  COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN session_id END)    AS awareness_sessions,
  COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN session_id END)    AS converted_sessions,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN session_id END),
                    COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN session_id END)
                    )  * 100, 1)                                      AS session_cvr_pct,
  ROUND(SUM(CASE WHEN stage_sequence = 6 THEN revenue END), 2)        AS revenue,
  ROUND(AVG(CASE WHEN stage_sequence = 6 THEN revenue END), 0)        AS aov,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN stage_sequence = 6 THEN revenue END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN session_id END)
  ), 2)                                                                  AS revenue_per_session
FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
GROUP BY region, traffic_source
ORDER BY region ASC, session_cvr_pct DESC;




--------- 4. Device & User Behavior ---------

-- 4.1 Funnel Performance by Device

-- 4.1.1 Funnel Summary
SELECT
  device_category,
  COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN session_id END)      AS awareness_sessions,
  COUNT(DISTINCT CASE WHEN stage_sequence = 6  THEN session_id END)      AS purchase_sessions,
  ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN session_id END),
                    COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN session_id END)
                    )  * 100, 1)                                         AS session_cvr_pct,
  ROUND(SUM(CASE WHEN stage_sequence = 6 THEN revenue END), 2)           AS revenue,
  ROUND(AVG(CASE WHEN stage_sequence = 6 THEN revenue END), 0)           AS aov,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN stage_sequence = 6 THEN revenue END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN session_id END)
  ), 2)                                                                  AS revenue_per_session
FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
GROUP BY device_category
ORDER BY session_cvr_pct DESC;

-- 4.1.2 Funnel Breakdown
WITH stage_counts AS (
  SELECT
    device_category,
    stage_sequence,
    stage_label,
    COUNT(DISTINCT session_id ) AS sessions
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  GROUP BY device_category, stage_sequence, stage_label
),

funnel_calc AS (
  SELECT
    device_category,
    stage_sequence,
    stage_label,
    sessions,
    LAG(sessions, 1) OVER (
      PARTITION BY device_category
      ORDER BY stage_sequence)      AS prev_stage_sessions
  FROM stage_counts
),

dropoff AS (
  SELECT
    stage_sequence,
    CASE stage_sequence
      WHEN 2 THEN 'Awareness → Product'
      WHEN 3 THEN 'Product → Cart'
      WHEN 4 THEN 'Cart → Checkout'
      WHEN 5 THEN 'Checkout → Payment'
      WHEN 6 THEN 'Payment → Purchase'
      END AS stage_transition,
    dropoff,
    ROUND((1 - SAFE_DIVIDE(sessions, prev_stage_sessions)) * 100, 1) AS dropoff_rate_pct
  FROM funnel_calc
)

SELECT
  stage_transition,
  MAX(CASE WHEN device_category = 'tablet'    THEN dropoff_rate_pct END)     AS Tablet,
  MAX(CASE WHEN device_category = 'desktop'   THEN dropoff_rate_pct END)     AS Desktop,
  MAX(CASE WHEN device_category = 'mobile'    THEN dropoff_rate_pct END)     AS Mobile,
FROM dropoff_by_device
WHERE stage_sequence != 1
GROUP BY stage_sequence, stage_transition
ORDER BY stage_sequence;



-- 4.2 Funnel Performance by User Type

-- 4.2.1 Funnel Summary
SELECT
  user_type,
  COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN user_id END)          AS awareness_users,
  COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN user_id END)          AS converted_users,
  ROUND(SAFE_DIVIDE(
    COUNT(DISTINCT CASE WHEN stage_sequence = 6 THEN user_id END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1 THEN user_id END)
  ) * 100, 1)                                                            AS true_cvr_pct,
  ROUND(SUM(CASE WHEN stage_sequence = 6 THEN revenue END), 2)           AS revenue,
  ROUND(AVG(CASE WHEN stage_sequence = 6 THEN revenue END), 0)           AS aov,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN stage_sequence = 6 THEN revenue END),
    COUNT(DISTINCT CASE WHEN stage_sequence = 1  THEN user_id END)
  ), 2)                                                                  AS revenue_per_user
FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
GROUP BY user_type
ORDER BY user_type;

-- 4.2.2 Funnel Drop-Off Breakdown
WITH stage_counts AS (
  SELECT
    user_type,
    stage_sequence,
    stage_label,
    COUNT(DISTINCT user_id ) AS users
  FROM `nn-marketing-funnel-analysis.web_events.vw_funnel_base`
  GROUP BY user_type, stage_sequence, stage_label
),

funnel_calc AS (
  SELECT
    user_type,
    stage_sequence,
    stage_label,
    users,
    LAG(users, 1) OVER (
      PARTITION BY user_type
      ORDER BY stage_sequence)      AS prev_stage_users
  FROM stage_counts
),

dropoff AS (
  SELECT
    stage_sequence,
    CASE stage_sequence
      WHEN 2 THEN 'Awareness → Product'
      WHEN 3 THEN 'Product → Cart'
      WHEN 4 THEN 'Cart → Checkout'
      WHEN 5 THEN 'Checkout → Payment'
      WHEN 6 THEN 'Payment → Purchase'
      END AS stage_transition,
    user_type,
    ROUND((1 - SAFE_DIVIDE(users, prev_stage_users)) * 100, 1) AS dropoff_rate_pct
  FROM funnel_calc
)

SELECT
  stage_transition,
  MAX(CASE WHEN user_type = 'new'       THEN dropoff_rate_pct END)     AS `New`,
  MAX(CASE WHEN user_type = 'returning' THEN dropoff_rate_pct END)     AS Returning
FROM dropoff
WHERE stage_sequence != 1
GROUP BY stage_sequence, stage_transition
ORDER BY stage_sequence;
