--======================================================================
-- Data Profiling
--======================================================================

--------- TABLE: raw_events ---------

-- 1. row counts

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT session_id) AS unique_sessions,
  COUNT(DISTINCT user_id) AS unique_users
FROM `nn-marketing-funnel-analysis.web_events.raw_events`;


-- 2. missing values

SELECT
  COUNTIF(event_id          IS NULL) AS null_event_ids,
  COUNTIF(session_id        IS NULL) AS null_session_ids,
  COUNTIF(user_id           IS NULL) AS null_user_ids,
  COUNTIF(event_timestamp   IS NULL) AS null_timestamp,
  COUNTIF(event_name        IS NULL) AS null_event_name,
  COUNTIF(device_category   IS NULL) AS null_device,
  COUNTIF(traffic_source    IS NULL) AS null_traffic,
  COUNTIF(campaign_name     IS NULL) AS null_campaign,
  COUNTIF(product_id        IS NULL) AS null_product,
  COUNTIF(product_category  IS NULL) AS null_product_cat,
  COUNTIF(cart_value        IS NULL) AS null_cart_value,
  COUNTIF(revenue           IS NULL) AS null_revenue
FROM `nn-marketing-funnel-analysis.web_events.raw_events`;


-- 2.1 campaign null logic check
SELECT
  traffic_source,
  COUNTIF(campaign_name   IS NULL) AS null_campaign,
  COUNTIF(campaign_name IS NOT NULL) AS count_campaign
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
GROUP BY traffic_source;


-- 2.2 product_id, cart_value, revenue null logic check
SELECT
  event_name,
  COUNTIF(product_id        IS NULL) AS null_product,
  COUNTIF(product_category  IS NULL) AS null_product_cat,
  COUNTIF(cart_value        IS NULL) AS null_cart_value,
  COUNTIF(revenue           IS NULL) AS null_revenue
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE event_name IS NOT NULL
GROUP BY event_name
ORDER BY null_product DESC, null_cart_value DESC, null_revenue DESC;


-- 3. numerical stats

SELECT
  MIN(cart_value) AS min_cart_value,
  MAX(cart_value) AS max_cart_value,
  AVG(cart_value) AS avg_cart_value,
  MIN(revenue ) AS min_revenue ,
  MAX(revenue ) AS max_revenue ,
  AVG(revenue ) AS avg_revenue ,
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE cart_value IS NOT NULL
   OR revenue IS NOT NULL;


-- 4. time period

SELECT
  MIN(DATE(event_timestamp)) AS earliest_date,
  MAX(DATE(event_timestamp)) AS latest_date,
  COUNT(DISTINCT DATE(event_timestamp)) AS days_with_data
FROM `nn-marketing-funnel-analysis.web_events.raw_events`;


-- 5. categorical column consistency

-- 5.1 event_name
SELECT
  event_name,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE event_name IS NOT NULL
GROUP BY event_name
ORDER BY count DESC, event_name ASC;

-- event_name, count unmatch stage_name from dim_stages
SELECT COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE event_name IS NOT NULL
  AND event_name NOT IN (
        SELECT stage_name 
        FROM `nn-marketing-funnel-analysis.web_events.dim_stages`);

-- 5.2 device_category
SELECT
  device_category,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE device_category IS NOT NULL
GROUP BY device_category
ORDER BY count DESC, device_category ASC;

-- device_category, non lowercase normalization
-- 1 desktop, 2 mobile, 3 tablet
SELECT COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE device_category IS NOT NULL
  AND device_category NOT IN ('desktop', 'mobile', 'tablet');

-- 5.3 traffic_source
SELECT
  traffic_source,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE traffic_source IS NOT NULL
GROUP BY traffic_source
ORDER BY count DESC;

-- 5.4 campaign_name
SELECT
  campaign_name,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE campaign_name IS NOT NULL
GROUP BY campaign_name
ORDER BY count DESC, campaign_name ASC;

-- campaign_name, count unmatch campaign_name from dim_campaigns
SELECT COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE campaign_name IS NOT NULL
  AND campaign_name NOT IN (
        SELECT campaign_name
        FROM `nn-marketing-funnel-analysis.web_events.dim_campaigns`);

-- 5.5 product_category
SELECT
  product_category,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE product_category IS NOT NULL
GROUP BY product_category
ORDER BY count DESC;


-- 6. orphaned key check

-- 6.1 events without matching session
SELECT COUNT(*) AS orphaned_events
FROM `nn-marketing-funnel-analysis.web_events.raw_events` AS e
LEFT JOIN `nn-marketing-funnel-analysis.web_events.raw_sessions` AS s
       ON e.session_id = s.session_id
WHERE s.session_id IS NULL;

-- 6.2 events without matching no user
SELECT COUNT(*) AS orphaned_users
FROM `nn-marketing-funnel-analysis.web_events.raw_events` AS e
LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_users` AS u
       ON e.user_id = u.user_id
WHERE u.user_id IS NULL;

-- 6.3 events without matching campaign (normalized + null excluded)
SELECT COUNT(*) AS unmatch_campaigns
FROM `nn-marketing-funnel-analysis.web_events.raw_events` AS e
LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_campaigns` AS c
       ON LOWER(TRIM(REPLACE(REPLACE(e.campaign_name, ' ', '_'), '-', '_'))) = c.campaign_name  -- replace ' ' and '-' with '_'
WHERE e.campaign_name IS NOT NULL
  AND c.campaign_name IS NULL;


-- 7. duplicate check
SELECT
  event_id,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
GROUP BY event_id
HAVING COUNT(*) > 1
ORDER BY count DESC;


--------- TABLE: raw_sessions ---------

-- 1. row counts

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT session_id) AS unique_sessions,
  COUNT(DISTINCT user_id) AS unique_users
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`;


-- 2. missing value

SELECT
  COUNTIF(session_id        IS NULL) AS null_session_ids,
  COUNTIF(user_id           IS NULL) AS null_user_ids,
  COUNTIF(session_start     IS NULL) AS null_session_start,
  COUNTIF(session_end       IS NULL) AS null_session_end,
  COUNTIF(session_duration  IS NULL) AS null_duration,
  COUNTIF(country           IS NULL) AS null_country,
  COUNTIF(traffic_source    IS NULL) AS null_traffic,
  COUNTIF(campaign_name     IS NULL) AS null_campaign,
  COUNTIF(device_category   IS NULL) AS null_device,
  COUNTIF(landing_page      IS NULL) AS null_landing,
  COUNTIF(exit_page         IS NULL) AS null_exit
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`;


-- 2.1 campaign null logic check
SELECT
  traffic_source,
  COUNTIF(campaign_name   IS NULL) AS null_campaign,
  COUNTIF(campaign_name   IS NOT NULL) AS count_campaign
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
GROUP BY traffic_source;


-- 3. time period

-- 3.1 session_start, session_end
SELECT
  MIN(DATE(session_start)) AS st_earliest_date,
  MAX(DATE(session_start)) AS st_latest_date,
  COUNT(DISTINCT DATE(session_start)) AS st_days_with_data,
  MIN(DATE(session_end)) AS end_earliest_date,
  MAX(DATE(session_end)) AS end_latest_date,
  COUNT(DISTINCT DATE(session_end)) AS end_days_with_data
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`;

-- 3.2 session_duration
SELECT session_duration
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
ORDER BY session_duration;

-- 4. categorical column consistency

-- 4.1 country
SELECT
  country,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
WHERE country IS NOT  NULL
GROUP BY country
ORDER BY count DESC;

-- country, count unmatch country_code from dim_regions
SELECT COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
WHERE country IS NOT NULL
  AND country NOT IN (
        SELECT country_code 
        FROM `nn-marketing-funnel-analysis.web_events.dim_regions`);

-- check matching with country_code or country from dim_regions
SELECT
  s.country           AS raw_country,
  r_code.country_code AS matched_by_code,
  r_name.country_code AS matched_by_name,
  COALESCE(r_code.country_code, r_name.country_code) AS resolved_code     -- try code match, then name match

FROM `nn-marketing-funnel-analysis.web_events.raw_sessions` AS s

LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_regions` AS r_code -- match raw_sessions.country to dim_regions.country_code
       ON UPPER(TRIM(s.country)) = r_code.country_code

LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_regions` AS r_name -- match raw_sessions.country to dim_regions.country
       ON LOWER(TRIM(s.country)) = LOWER(r_name.country)

GROUP BY s.country, r_code.country_code, r_name.country_code
ORDER BY resolved_code NULLS FIRST;

-- 4.2 traffic_source
SELECT
  traffic_source,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
WHERE traffic_source IS NOT  NULL
GROUP BY traffic_source
ORDER BY count DESC;

-- 4.3 campaign_name
SELECT
  campaign_name,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
WHERE campaign_name IS NOT  NULL
GROUP BY campaign_name
ORDER BY count DESC;

-- check unmatch campaign_name
SELECT DISTINCT
  s.campaign_name,
  c.campaign_name
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions` AS s
LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_campaigns` AS c
       ON s.campaign_name = c.campaign_name
WHERE s.campaign_name IS NOT NULL;

-- 4.4 device_category
SELECT
  device_category,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
WHERE device_category IS NOT  NULL
GROUP BY device_category
ORDER BY count DESC;

-- 4.5 landing_page
SELECT
  landing_page,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
WHERE landing_page IS NOT  NULL
GROUP BY landing_page
ORDER BY count DESC;

-- 4.6 exit_page
SELECT
  exit_page,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
WHERE exit_page IS NOT  NULL
GROUP BY exit_page
ORDER BY count DESC;


-- 5. duplicate check
SELECT
  session_id,
  COUNT(*) AS count
FROM `nn-marketing-funnel-analysis.web_events.raw_sessions`
GROUP BY session_id
HAVING COUNT(*) > 1
ORDER BY count DESC;

