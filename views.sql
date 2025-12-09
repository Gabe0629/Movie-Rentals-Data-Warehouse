-- ============================================
-- WEEK 4: VIEWS CREATION
-- ============================================

-- View 1: Customer Value Analysis
CREATE VIEW IF NOT EXISTS v_customer_value AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name as customer_name,
    c.city,
    c.state,
    c.join_date,
    c.loyalty_tier,
    COUNT(r.rental_id) as total_rentals,
    SUM(r.rental_fee + r.late_fee) as lifetime_value,
    COUNT(DISTINCT m.genre) as genres_rented,
    COUNT(DISTINCT s.store_id) as stores_used,
    MIN(r.rental_date) as first_rental_date,
    MAX(r.rental_date) as last_rental_date,
    CASE 
        WHEN MAX(r.rental_date) IS NULL THEN NULL
        ELSE JULIANDAY(DATE('now')) - JULIANDAY(MAX(r.rental_date))
    END as days_since_last_rental,
    ROUND(AVG(r.rental_fee + r.late_fee), 2) as avg_transaction_value,
    SUM(r.late_fee) as total_late_fees_paid
FROM customers c
LEFT JOIN rentals r ON c.customer_id = r.customer_id
LEFT JOIN movies m ON r.movie_id = m.movie_id
LEFT JOIN stores s ON r.store_id = s.store_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.city, c.state, c.join_date, c.loyalty_tier;

-- View 2: Store Performance Dashboard
CREATE VIEW IF NOT EXISTS v_store_performance AS
WITH store_metrics AS (
    SELECT 
        s.store_id,
        s.store_name,
        s.city as store_city,
        s.state as store_state,
        s.opened_date,
        COUNT(DISTINCT r.customer_id) as unique_customers,
        COUNT(r.rental_id) as total_rentals,
        SUM(r.rental_fee + r.late_fee) as total_revenue,
        SUM(r.late_fee) as late_fee_revenue,
        COUNT(CASE WHEN r.late_fee > 0 THEN 1 END) as late_returns_count,
        COUNT(DISTINCT m.genre) as unique_genres_offered,
        COUNT(DISTINCT m.movie_id) as unique_movies_rented
    FROM stores s
    LEFT JOIN rentals r ON s.store_id = r.store_id
    LEFT JOIN movies m ON r.movie_id = m.movie_id
    GROUP BY s.store_id, s.store_name, s.city, s.state, s.opened_date
)
SELECT 
    store_id,
    store_name,
    store_city,
    store_state,
    opened_date,
    unique_customers,
    total_rentals,
    total_revenue,
    late_fee_revenue,
    unique_genres_offered,
    unique_movies_rented,
    ROUND(total_revenue * 1.0 / NULLIF(total_rentals, 0), 2) as avg_transaction_value,
    ROUND(late_fee_revenue * 100.0 / NULLIF(total_revenue, 0), 2) as late_fee_percentage,
    ROUND(total_rentals * 1.0 / NULLIF(JULIANDAY(DATE('now')) - JULIANDAY(opened_date), 0) * 365, 2) as annualized_rentals,
    ROUND(total_revenue * 1.0 / NULLIF(JULIANDAY(DATE('now')) - JULIANDAY(opened_date), 0) * 365, 2) as annualized_revenue
FROM store_metrics;

-- View 3: Movie Popularity Analysis
CREATE VIEW IF NOT EXISTS v_movie_popularity AS
WITH movie_rental_stats AS (
    SELECT 
        m.movie_id,
        m.title,
        m.genre,
        m.release_year,
        m.rating,
        m.daily_rental_rate,
        m.total_copies,
        COUNT(r.rental_id) as total_rentals,
        COUNT(DISTINCT r.customer_id) as unique_customers,
        COUNT(DISTINCT r.store_id) as stores_available_in,
        SUM(r.rental_fee + r.late_fee) as total_revenue_generated,
        MIN(r.rental_date) as first_rental_date,
        MAX(r.rental_date) as last_rental_date,
        COUNT(CASE WHEN r.late_fee > 0 THEN 1 END) as late_returns_count
    FROM movies m
    LEFT JOIN rentals r ON m.movie_id = r.movie_id
    GROUP BY m.movie_id, m.title, m.genre, m.release_year, m.rating, m.daily_rental_rate, m.total_copies
)
SELECT 
    movie_id,
    title,
    genre,
    release_year,
    rating,
    daily_rental_rate,
    total_copies,
    total_rentals,
    unique_customers,
    stores_available_in,
    total_revenue_generated,
    first_rental_date,
    last_rental_date,
    late_returns_count,
    ROUND(total_rentals * 1.0 / NULLIF(total_copies, 0), 2) as rentals_per_copy,
    ROUND(total_revenue_generated * 1.0 / NULLIF(total_rentals, 0), 2) as avg_revenue_per_rental,
    CASE 
        WHEN first_rental_date IS NULL THEN 'Never Rented'
        ELSE CAST(JULIANDAY(DATE('now')) - JULIANDAY(first_rental_date) AS TEXT) || ' days'
    END as days_since_first_rental,
    ROUND(late_returns_count * 100.0 / NULLIF(total_rentals, 0), 2) as late_return_rate
FROM movie_rental_stats
ORDER BY total_rentals DESC;