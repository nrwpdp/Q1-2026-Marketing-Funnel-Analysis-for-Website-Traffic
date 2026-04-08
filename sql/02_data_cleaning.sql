--======================================================================
-- Data Cleaning & Transformation
--======================================================================

--------- TABLE: raw_events ---------

-- 1. normalize event_name to match with stage_name in dim_stages
-- funnel stages: 1) awareness -> 2) product_view -> 3) add_to_cart -> 4) checkout -> 5) payment -> 6) purchace

SELECT
  CASE  WHEN TRIM(LOWER(event_name)) IN ('awareness', 'landing_page', 'landing page', 'landingpage')
          THEN 'awareness'
        WHEN TRIM(LOWER(event_name)) IN ('product_view', 'product view', 'productview', 'view_product')
          THEN 'product_view'
        WHEN TRIM(LOWER(event_name)) IN ('addtocart', 'add to cart', 'add_to_cart')
          THEN 'add_to_cart'
        WHEN TRIM(LOWER(event_name)) IN ('checkout_start', 'checkout', 'begin_checkout', 'begin checkout')
          THEN 'checkout'
        WHEN TRIM(LOWER(event_name)) IN ('payment_info', 'payment', 'add_payment_info')
          THEN 'payment'
        WHEN TRIM(LOWER(event_name)) IN ('purchase', 'transaction', 'order_complete')
          THEN 'purchase'
        ELSE NULL
    END AS stage_name,

FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE event_name IS NOT NULL;


-- 2. normalize device_category into lowercase with no abbreviation

SELECT
  CASE  WHEN TRIM(LOWER(device_category)) IN ('desktop')       THEN 'desktop'
        WHEN TRIM(LOWER(device_category)) IN ('mobile', 'mob') THEN 'mobile'
        WHEN TRIM(LOWER(device_category)) IN ('tablet')        THEN 'tablet'
        ELSE NULL
    END AS device_category,
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE event_name IS NOT NULL;


-- 3. normalize campaign_name to match with campaign_name in dim_campaigns
-- replace ' ' and '-' with '_'

SELECT
  CASE WHEN campaign_name IS NULL THEN NULL
       ELSE LOWER(TRIM(REPLACE(REPLACE(campaign_name, ' ', '_'), '-', '_')))
    END AS campaign_name
FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE event_name IS NOT NULL;

/*  -- check unique campaigns from raw_events and dim_campaigns
  WITH ec AS (
    SELECT DISTINCT
        CASE WHEN campaign_name IS NULL THEN NULL  -- preserve organic/direct nulls
        ELSE LOWER(TRIM(REPLACE(REPLACE(campaign_name, ' ', '_'), '-', '_')))
    END AS campaign_name    FROM `nn-marketing-funnel-analysis.web_events.raw_events`
    WHERE event_name IS NOT NULL
      AND campaign_name IS NOT NULL
  )

  SELECT campaign_name
  FROM `nn-marketing-funnel-analysis.web_events.dim_campaigns`
  EXCEPT DISTINCT
  SELECT campaign_name
  FROM ec;

-- only eu_brand_awareness is not existed in raw_events*/


-- CLEANED events view (for Tableau star schema)
CREATE OR REPLACE VIEW `nn-marketing-funnel-analysis.web_events.vw_cleaned_events` AS

SELECT
  event_id,
  session_id,
  user_id,
  event_timestamp,

  -- normalized event_name to stage_name
  CASE  WHEN TRIM(LOWER(event_name)) IN ('awareness', 'landing_page', 'landing page', 'landingpage')
          THEN 'awareness'
        WHEN TRIM(LOWER(event_name)) IN ('product_view', 'product view', 'productview', 'view_product')
          THEN 'product_view'
        WHEN TRIM(LOWER(event_name)) IN ('addtocart', 'add to cart', 'add_to_cart')
          THEN 'add_to_cart'
        WHEN TRIM(LOWER(event_name)) IN ('checkout_start', 'checkout', 'begin_checkout', 'begin checkout')
          THEN 'checkout'
        WHEN TRIM(LOWER(event_name)) IN ('payment_info', 'payment', 'add_payment_info')
          THEN 'payment'
        WHEN TRIM(LOWER(event_name)) IN ('purchase', 'transaction', 'order_complete')
          THEN 'purchase'
        ELSE NULL
    END AS stage_name,

  -- normalized device_category
  CASE  WHEN TRIM(LOWER(device_category)) IN ('desktop')       THEN 'desktop'
        WHEN TRIM(LOWER(device_category)) IN ('mobile', 'mob') THEN 'mobile'
        WHEN TRIM(LOWER(device_category)) IN ('tablet')        THEN 'tablet'
        ELSE NULL
    END AS device_category,
  
  traffic_source,

  -- normalized campaign_name to lowercase + underscore format
  CASE  WHEN campaign_name IS NULL THEN NULL
        ELSE LOWER(TRIM(REPLACE(REPLACE(campaign_name, ' ', '_'), '-', '_')))
    END AS campaign_name,

  product_id,
  product_category,
  cart_value,
  revenue

FROM `nn-marketing-funnel-analysis.web_events.raw_events`
WHERE event_name IS NOT NULL;




--------- TABLE: raw_sessions ---------

-- 1. parse session_duration into INTERGER seconds

SELECT
  CASE  WHEN REGEXP_CONTAINS(session_duration, r'^\d+m \d+s$')                   -- case: 5m 32s (Xm Ys)
          THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)m') AS INT64) * 60  -- extract value from 'm' * 60
             + CAST(REGEXP_EXTRACT(session_duration, r'(\d+)s$') AS INT64)       -- plus the value from 's'
       
        WHEN REGEXP_CONTAINS(session_duration, r'^\d+s$')                        -- case: 332s (Ys)
          THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)s$') AS INT64)      -- extract value from 's'
       
        ELSE NULL
    END AS session_duration_sec,

FROM`nn-marketing-funnel-analysis.web_events.raw_sessions`
ORDER BY session_duration_sec;


-- 2. normalize country to ISO 2-letter code

SELECT
  CASE  WHEN TRIM(LOWER(country)) IN ('ae', 'united arab emirates',	'uae')   THEN 'AE' 
        WHEN TRIM(LOWER(country)) IN ('ar', 'argentina')                     THEN 'AR' 
        WHEN TRIM(LOWER(country)) IN ('au', 'australia')                     THEN 'AU' 
        WHEN TRIM(LOWER(country)) IN ('br', 'brazil')                        THEN 'BR' 
        WHEN TRIM(LOWER(country)) IN ('ca', 'canada')                        THEN 'CA' 
        WHEN TRIM(LOWER(country)) IN ('cl', 'chile')                         THEN 'CL' 
        WHEN TRIM(LOWER(country)) IN ('cn', 'china')                         THEN 'CN' 
        WHEN TRIM(LOWER(country)) IN ('co', 'colombia')                      THEN 'CO' 
        WHEN TRIM(LOWER(country)) IN ('de', 'deutschland','germany')         THEN 'DE' 
        WHEN TRIM(LOWER(country)) IN ('fr', 'france')                        THEN 'FR' 
        WHEN TRIM(LOWER(country)) IN ('uk', 'united kingdom',	'gb')          THEN 'GB' 
        WHEN TRIM(LOWER(country)) IN ('in', 'india')                         THEN 'IN' 
        WHEN TRIM(LOWER(country)) IN ('it', 'italy')                         THEN 'IT' 
        WHEN TRIM(LOWER(country)) IN ('jp', 'japan')                         THEN 'JP' 
        WHEN TRIM(LOWER(country)) IN ('mx', 'mexico')                        THEN 'MX' 
        WHEN TRIM(LOWER(country)) IN ('sg', 'singapore')                     THEN 'SG' 
        WHEN TRIM(LOWER(country)) IN ('th', 'thailand')                      THEN 'TH' 
        WHEN TRIM(LOWER(country)) IN ('us', 'united states',	'usa')         THEN 'US' 
        WHEN TRIM(LOWER(country)) IN ('za', 'south africa')                  THEN 'ZA' 
        ELSE NULL
    END AS country,
FROM`nn-marketing-funnel-analysis.web_events.raw_sessions`;


-- CLEANED sessions view (for Tableau star schema)
CREATE OR REPLACE VIEW `nn-marketing-funnel-analysis.web_events.vw_cleaned_sessions` AS

SELECT
  session_id, 
  user_id, 
  session_start, 
  session_end,
  
  -- parse session_duration into INTERGER seconds
  CASE WHEN REGEXP_CONTAINS(session_duration, r'^\d+m \d+s$')                  -- case: 5m 32s (Xm Ys)
        THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)m') AS INT64) * 60  -- extract value from 'm' * 60
           + CAST(REGEXP_EXTRACT(session_duration, r'(\d+)s$') AS INT64)       -- plus the value from 's'
       
       WHEN REGEXP_CONTAINS(session_duration, r'^\d+s$')                       -- case: 332s (Ys)
        THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)s$') AS INT64)      -- extract value from 's'
       
       ELSE NULL
    END AS session_duration_sec,

  -- normalize country to ISO 2-letter code
  CASE  WHEN TRIM(LOWER(country)) IN ('ae', 'united arab emirates',	'uae')   THEN 'AE' 
        WHEN TRIM(LOWER(country)) IN ('ar', 'argentina')                     THEN 'AR' 
        WHEN TRIM(LOWER(country)) IN ('au', 'australia')                     THEN 'AU' 
        WHEN TRIM(LOWER(country)) IN ('br', 'brazil')                        THEN 'BR' 
        WHEN TRIM(LOWER(country)) IN ('ca', 'canada')                        THEN 'CA' 
        WHEN TRIM(LOWER(country)) IN ('cl', 'chile')                         THEN 'CL' 
        WHEN TRIM(LOWER(country)) IN ('cn', 'china')                         THEN 'CN' 
        WHEN TRIM(LOWER(country)) IN ('co', 'colombia')                      THEN 'CO' 
        WHEN TRIM(LOWER(country)) IN ('de', 'deutschland','germany')         THEN 'DE' 
        WHEN TRIM(LOWER(country)) IN ('fr', 'france')                        THEN 'FR' 
        WHEN TRIM(LOWER(country)) IN ('uk', 'united kingdom',	'gb')          THEN 'GB' 
        WHEN TRIM(LOWER(country)) IN ('in', 'india')                         THEN 'IN' 
        WHEN TRIM(LOWER(country)) IN ('it', 'italy')                         THEN 'IT' 
        WHEN TRIM(LOWER(country)) IN ('jp', 'japan')                         THEN 'JP' 
        WHEN TRIM(LOWER(country)) IN ('mx', 'mexico')                        THEN 'MX' 
        WHEN TRIM(LOWER(country)) IN ('sg', 'singapore')                     THEN 'SG' 
        WHEN TRIM(LOWER(country)) IN ('th', 'thailand')                      THEN 'TH' 
        WHEN TRIM(LOWER(country)) IN ('us', 'united states',	'usa')         THEN 'US' 
        WHEN TRIM(LOWER(country)) IN ('za', 'south africa')                  THEN 'ZA' 
        ELSE NULL
    END AS country,

  traffic_source,
  campaign_name, 
  device_category,
  landing_page, 
  exit_page
FROM`nn-marketing-funnel-analysis.web_events.raw_sessions`;



--======================================================================
-- FINAL VIEW: vw_funnel_base for analysis
--======================================================================

/* -- validate matching info after join
    WITH cleaned_events AS(
      SELECT
        event_id,
        session_id,
        user_id,
        event_timestamp,

        -- normalized event_name to stage_name
        CASE  WHEN TRIM(LOWER(event_name)) IN ('awareness', 'landing_page', 'landing page', 'landingpage')
                THEN 'awareness'
              WHEN TRIM(LOWER(event_name)) IN ('product_view', 'product view', 'productview', 'view_product')
                THEN 'product_view'
              WHEN TRIM(LOWER(event_name)) IN ('addtocart', 'add to cart', 'add_to_cart')
                THEN 'add_to_cart'
              WHEN TRIM(LOWER(event_name)) IN ('checkout_start', 'checkout', 'begin_checkout', 'begin checkout')
                THEN 'checkout'
              WHEN TRIM(LOWER(event_name)) IN ('payment_info', 'payment', 'add_payment_info')
                THEN 'payment'
              WHEN TRIM(LOWER(event_name)) IN ('purchase', 'transaction', 'order_complete')
                THEN 'purchase'
              ELSE NULL
          END AS stage_name,

        -- normalized device_category
        CASE  WHEN TRIM(LOWER(device_category)) IN ('desktop')       THEN 'desktop'
              WHEN TRIM(LOWER(device_category)) IN ('mobile', 'mob') THEN 'mobile'
              WHEN TRIM(LOWER(device_category)) IN ('tablet')        THEN 'tablet'
              ELSE NULL
          END AS device_category,
      
        traffic_source,

        -- normalized campaign_name to lowercase + underscore format
        CASE  WHEN campaign_name IS NULL THEN NULL
              ELSE LOWER(TRIM(REPLACE(REPLACE(campaign_name, ' ', '_'), '-', '_')))
          END AS campaign_name,

        product_id,
        product_category,
        cart_value,
        revenue

      FROM `nn-marketing-funnel-analysis.web_events.raw_events`
      WHERE event_name IS NOT NULL
    ),

    cleaned_sessions AS(
      SELECT
        session_id, 
        user_id, 
        session_start, 
        session_end,
      
        -- parse session_duration into INTERGER seconds
        CASE  WHEN REGEXP_CONTAINS(session_duration, r'^\d+m \d+s$')                  -- case: 5m 32s (Xm Ys)
                THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)m') AS INT64) * 60  -- extract value from 'm' * 60
                  + CAST(REGEXP_EXTRACT(session_duration, r'(\d+)s$') AS INT64)       -- plus the value from 's'
          
              WHEN REGEXP_CONTAINS(session_duration, r'^\d+s$')                       -- case: 332s (Ys)
                THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)s$') AS INT64)      -- extract value from 's'
          
              ELSE NULL
          END AS session_duration_sec,

        -- normalize country to ISO 2-letter code
        CASE  WHEN TRIM(LOWER(country)) IN ('ae', 'united arab emirates',	'uae')   THEN 'AE' 
              WHEN TRIM(LOWER(country)) IN ('ar', 'argentina')                     THEN 'AR' 
              WHEN TRIM(LOWER(country)) IN ('au', 'australia')                     THEN 'AU' 
              WHEN TRIM(LOWER(country)) IN ('br', 'brazil')                        THEN 'BR' 
              WHEN TRIM(LOWER(country)) IN ('ca', 'canada')                        THEN 'CA' 
              WHEN TRIM(LOWER(country)) IN ('cl', 'chile')                         THEN 'CL' 
              WHEN TRIM(LOWER(country)) IN ('cn', 'china')                         THEN 'CN' 
              WHEN TRIM(LOWER(country)) IN ('co', 'colombia')                      THEN 'CO' 
              WHEN TRIM(LOWER(country)) IN ('de', 'deutschland','germany')         THEN 'DE' 
              WHEN TRIM(LOWER(country)) IN ('fr', 'france')                        THEN 'FR' 
              WHEN TRIM(LOWER(country)) IN ('uk', 'united kingdom',	'gb')          THEN 'GB' 
              WHEN TRIM(LOWER(country)) IN ('in', 'india')                         THEN 'IN' 
              WHEN TRIM(LOWER(country)) IN ('it', 'italy')                         THEN 'IT' 
              WHEN TRIM(LOWER(country)) IN ('jp', 'japan')                         THEN 'JP' 
              WHEN TRIM(LOWER(country)) IN ('mx', 'mexico')                        THEN 'MX' 
              WHEN TRIM(LOWER(country)) IN ('sg', 'singapore')                     THEN 'SG' 
              WHEN TRIM(LOWER(country)) IN ('th', 'thailand')                      THEN 'TH' 
              WHEN TRIM(LOWER(country)) IN ('us', 'united states',	'usa')         THEN 'US' 
              WHEN TRIM(LOWER(country)) IN ('za', 'south africa')                  THEN 'ZA' 
              ELSE NULL
          END AS country,

        traffic_source,
        campaign_name, 
        device_category,
        landing_page, 
        exit_page
      FROM`nn-marketing-funnel-analysis.web_events.raw_sessions`
    )

  -- 1. device_category | events, sessions
    SELECT 
      ce.device_category AS e,
      cs.device_category AS s,
      COUNT(*)
    FROM cleaned_events AS ce
    LEFT JOIN cleaned_sessions AS cs 
          ON ce.session_id = cs.session_id
    GROUP BY ce.device_category, cs.device_category;

  -- 2. country | sessions, dim_users, dim_regions
    SELECT
      cs.country AS s,
      du.country AS u,
      dr.country AS r,
      COUNT(*)
    FROM cleaned_events AS ce

    LEFT JOIN cleaned_sessions AS cs 
          ON ce.session_id = cs.session_id

    LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_users`     AS du
          ON ce.user_id = du.user_id
    
    LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_regions`   AS dr
          ON cs.country = dr.country_code

    GROUP BY cs.country, du.country, dr.country;

  -- 3. traffic_source | events, sessions
    SELECT 
      ce.traffic_source AS e,
      cs.traffic_source AS s,
      COUNT(*)
    FROM cleaned_events AS ce
    LEFT JOIN cleaned_sessions AS cs 
          ON ce.session_id = cs.session_id
    GROUP BY ce.traffic_source, cs.traffic_source;

  -- 4. campaign_name | events, sessions, dim_campaigns
    SELECT 
      ce.campaign_name AS e,
      cs.campaign_name AS s,
      dc.campaign_name AS c,
      COUNT(*)
    FROM cleaned_events AS ce

    LEFT JOIN cleaned_sessions AS cs 
          ON ce.session_id = cs.session_id

    LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_campaigns` AS dc
          ON ce.campaign_name = dc.campaign_name
          
    GROUP BY ce.campaign_name, cs.campaign_name, dc.campaign_name;
*/


-- create view

CREATE OR REPLACE VIEW `nn-marketing-funnel-analysis.web_events.vw_funnel_base` AS

  WITH cleaned_events AS(
    SELECT
      event_id,
      session_id,
      user_id,
      event_timestamp,

      -- normalized event_name to stage_name
      CASE  WHEN TRIM(LOWER(event_name)) IN ('awareness', 'landing_page', 'landing page', 'landingpage')
              THEN 'awareness'
            WHEN TRIM(LOWER(event_name)) IN ('product_view', 'product view', 'productview', 'view_product')
              THEN 'product_view'
            WHEN TRIM(LOWER(event_name)) IN ('addtocart', 'add to cart', 'add_to_cart')
              THEN 'add_to_cart'
            WHEN TRIM(LOWER(event_name)) IN ('checkout_start', 'checkout', 'begin_checkout', 'begin checkout')
              THEN 'checkout'
            WHEN TRIM(LOWER(event_name)) IN ('payment_info', 'payment', 'add_payment_info')
              THEN 'payment'
            WHEN TRIM(LOWER(event_name)) IN ('purchase', 'transaction', 'order_complete')
              THEN 'purchase'
            ELSE NULL
        END AS stage_name,

      -- normalized device_category
      CASE  WHEN TRIM(LOWER(device_category)) IN ('desktop')       THEN 'desktop'
            WHEN TRIM(LOWER(device_category)) IN ('mobile', 'mob') THEN 'mobile'
            WHEN TRIM(LOWER(device_category)) IN ('tablet')        THEN 'tablet'
            ELSE NULL
        END AS device_category,
    
      traffic_source,

      -- normalized campaign_name to lowercase + underscore format
      CASE  WHEN campaign_name IS NULL THEN NULL
            ELSE LOWER(TRIM(REPLACE(REPLACE(campaign_name, ' ', '_'), '-', '_')))
        END AS campaign_name,

      product_id,
      product_category,
      cart_value,
      revenue

    FROM `nn-marketing-funnel-analysis.web_events.raw_events`
    WHERE event_name IS NOT NULL
  ),

  cleaned_sessions AS(
    SELECT
      session_id, 
      user_id, 
      session_start, 
      session_end,
    
      -- parse session_duration into INTERGER seconds
      CASE  WHEN REGEXP_CONTAINS(session_duration, r'^\d+m \d+s$')                  -- case: 5m 32s (Xm Ys)
              THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)m') AS INT64) * 60  -- extract value from 'm' * 60
                 + CAST(REGEXP_EXTRACT(session_duration, r'(\d+)s$') AS INT64)       -- plus the value from 's'
        
            WHEN REGEXP_CONTAINS(session_duration, r'^\d+s$')                       -- case: 332s (Ys)
              THEN CAST(REGEXP_EXTRACT(session_duration, r'^(\d+)s$') AS INT64)      -- extract value from 's'
        
            ELSE NULL
        END AS session_duration_sec,

      -- normalize country to ISO 2-letter code
      CASE  WHEN TRIM(LOWER(country)) IN ('ae', 'united arab emirates',	'uae')   THEN 'AE' 
            WHEN TRIM(LOWER(country)) IN ('ar', 'argentina')                     THEN 'AR' 
            WHEN TRIM(LOWER(country)) IN ('au', 'australia')                     THEN 'AU' 
            WHEN TRIM(LOWER(country)) IN ('br', 'brazil')                        THEN 'BR' 
            WHEN TRIM(LOWER(country)) IN ('ca', 'canada')                        THEN 'CA' 
            WHEN TRIM(LOWER(country)) IN ('cl', 'chile')                         THEN 'CL' 
            WHEN TRIM(LOWER(country)) IN ('cn', 'china')                         THEN 'CN' 
            WHEN TRIM(LOWER(country)) IN ('co', 'colombia')                      THEN 'CO' 
            WHEN TRIM(LOWER(country)) IN ('de', 'deutschland','germany')         THEN 'DE' 
            WHEN TRIM(LOWER(country)) IN ('fr', 'france')                        THEN 'FR' 
            WHEN TRIM(LOWER(country)) IN ('uk', 'united kingdom',	'gb')          THEN 'GB' 
            WHEN TRIM(LOWER(country)) IN ('in', 'india')                         THEN 'IN' 
            WHEN TRIM(LOWER(country)) IN ('it', 'italy')                         THEN 'IT' 
            WHEN TRIM(LOWER(country)) IN ('jp', 'japan')                         THEN 'JP' 
            WHEN TRIM(LOWER(country)) IN ('mx', 'mexico')                        THEN 'MX' 
            WHEN TRIM(LOWER(country)) IN ('sg', 'singapore')                     THEN 'SG' 
            WHEN TRIM(LOWER(country)) IN ('th', 'thailand')                      THEN 'TH' 
            WHEN TRIM(LOWER(country)) IN ('us', 'united states',	'usa')         THEN 'US' 
            WHEN TRIM(LOWER(country)) IN ('za', 'south africa')                  THEN 'ZA' 
            ELSE NULL
        END AS country,

      traffic_source,
      campaign_name, 
      device_category,
      landing_page, 
      exit_page
    FROM`nn-marketing-funnel-analysis.web_events.raw_sessions`
  )

  SELECT
    -- events info
    ce.event_id,
    ce.event_timestamp,
    ce.device_category,
    ce.traffic_source,
    ce.product_id,
    ce.product_category,
    ce.cart_value,
    ce.revenue,
  
    -- stages info
    ce.stage_name,
    ds.stage_sequence,
    ds.stage_label,

    -- sessions info
    ce.session_id,
    cs.session_start,
    cs.session_end,
    cs.session_duration_sec,
    cs.landing_page,
    cs.exit_page,

    -- campaigns info
    ce.campaign_name,
    dc.channel,
    dc.budget,

    -- users info
    ce.user_id,
    du.user_type,
    du.first_seen_date,
    du.lifetime_orders,

    -- regions info
    cs.country AS country_code,
    dr.country AS country_name,
    dr.region

  FROM cleaned_events AS ce

  LEFT JOIN cleaned_sessions AS cs 
         ON ce.session_id = cs.session_id

  LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_users`     AS du
         ON ce.user_id = du.user_id
  
  LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_campaigns` AS dc
         ON ce.campaign_name = dc.campaign_name
  
  LEFT JOIN `nn-marketing-funnel-analysis.web_events.dim_regions`   AS dr
         ON cs.country = dr.country_code

  INNER JOIN `nn-marketing-funnel-analysis.web_events.dim_stages`   AS ds
          ON ce.stage_name = ds.stage_name;











