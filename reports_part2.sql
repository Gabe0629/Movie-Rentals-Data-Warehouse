-- 8. Top customers by revenue (YTD)
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name as customer_name,
    c.city,
    c.state,
    c.loyalty_tier,
    COUNT(r.rental_id) as rental_count,
    SUM(r.rental_fee + r.late_fee) as total_spent,
    ROUND(AVG(r.rental_fee + r.late_fee), 2) as avg_transaction_value,
    MIN(r.rental_date) as first_rental_date,
    MAX(r.rental_date) as last_rental_date
FROM rentals r
JOIN customers c ON r.customer_id = c.customer_id
JOIN dates d ON r.date_id = d.date_id
WHERE d.year = 2024
GROUP BY c.customer_id, c.first_name, c.last_name, c.city, c.state, c.loyalty_tier
HAVING rental_count >= 3
ORDER BY total_spent DESC
LIMIT 10;

-- 9. Repeat rentals (customers renting same movie ≥ 3 times)
WITH repeat_rentals AS (
    SELECT 
        r.customer_id,
        r.movie_id,
        COUNT(r.rental_id) as times_rented,
        MIN(r.rental_date) as first_rental,
        MAX(r.rental_date) as last_rental
    FROM rentals r
    GROUP BY r.customer_id, r.movie_id
    HAVING COUNT(r.rental_id) >= 3
)
SELECT 
    c.first_name || ' ' || c.last_name as customer_name,
    m.title,
    m.genre,
    rr.times_rented,
    rr.first_rental,
    rr.last_rental,
    DATEDIFF(rr.last_rental, rr.first_rental) as days_between_first_last
FROM repeat_rentals rr
JOIN customers c ON rr.customer_id = c.customer_id
JOIN movies m ON rr.movie_id = m.movie_id
ORDER BY rr.times_rented DESC, customer_name;

-- 10. Movie utilization: rentals per movie vs. total copies
WITH movie_stats AS (
    SELECT 
        m.movie_id,
        m.title,
        m.genre,
        m.total_copies,
        COUNT(r.rental_id) as total_rentals,
        COUNT(DISTINCT r.date_id) as days_rented,
        SUM(r.rental_fee + r.late_fee) as total_revenue
    FROM movies m
    LEFT JOIN rentals r ON m.movie_id = r.movie_id
    GROUP BY m.movie_id, m.title, m.genre, m.total_copies
)
SELECT 
    movie_id,
    title,
    genre,
    total_copies,
    total_rentals,
    days_rented,
    total_revenue,
    ROUND(total_rentals * 1.0 / NULLIF(total_copies, 0), 2) as rentals_per_copy,
    ROUND(days_rented * 1.0 / 365 * 100, 2) as yearly_utilization_pct,
    ROUND(total_revenue / NULLIF(total_copies, 0), 2) as revenue_per_copy
FROM movie_stats
ORDER BY rentals_per_copy DESC
LIMIT 15;

-- 11. Store revenue share (%)
WITH store_revenue AS (
    SELECT 
        s.store_id,
        s.store_name,
        s.city,
        COUNT(r.rental_id) as rental_count,
        SUM(r.rental_fee + r.late_fee) as total_revenue
    FROM rentals r
    JOIN stores s ON r.store_id = s.store_id
    GROUP BY s.store_id, s.store_name, s.city
),
total_revenue AS (
    SELECT SUM(total_revenue) as grand_total FROM store_revenue
)
SELECT 
    sr.store_name,
    sr.city,
    sr.rental_count,
    sr.total_revenue,
    ROUND(sr.total_revenue * 100.0 / tr.grand_total, 2) as revenue_share_percentage,
    ROUND(sr.total_revenue * 1.0 / sr.rental_count, 2) as avg_revenue_per_rental
FROM store_revenue sr
CROSS JOIN total_revenue tr
ORDER BY revenue_share_percentage DESC;

-- 12. Customer retention (rentals within 90 days of joining)
WITH customer_first_rental AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name as customer_name,
        c.join_date,
        MIN(r.rental_date) as first_rental_date
    FROM customers c
    LEFT JOIN rentals r ON c.customer_id = r.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.join_date
)
SELECT 
    customer_name,
    join_date,
    first_rental_date,
    CASE 
        WHEN first_rental_date IS NULL THEN 'No rentals yet'
        WHEN JULIANDAY(first_rental_date) - JULIANDAY(join_date) <= 90 
            THEN 'Retained (rented within 90 days)'
        ELSE 'Not retained (first rental after 90 days)'
    END as retention_status,
    CASE 
        WHEN first_rental_date IS NULL THEN NULL
        ELSE JULIANDAY(first_rental_date) - JULIANDAY(join_date)
    END as days_to_first_rental
FROM customer_first_rental
ORDER BY days_to_first_rental;

-- 13. Seasonal rentals by quarter
SELECT 
    d.year,
    d.quarter,
    m.genre,
    COUNT(r.rental_id) as rental_count,
    SUM(r.rental_fee + r.late_fee) as quarterly_revenue,
    ROUND(AVG(r.rental_fee + r.late_fee), 2) as avg_rental_value,
    ROUND(
        COUNT(r.rental_id) * 100.0 / SUM(COUNT(r.rental_id)) OVER (PARTITION BY d.year, d.quarter),
        2
    ) as genre_share_percentage
FROM rentals r
JOIN dates d ON r.date_id = d.date_id
JOIN movies m ON r.movie_id = m.movie_id
GROUP BY d.year, d.quarter, m.genre
ORDER BY d.year DESC, d.quarter, quarterly_revenue DESC;

-- 14. Top genres per store (rank with window function)
WITH store_genre_stats AS (
    SELECT 
        s.store_id,
        s.store_name,
        m.genre,
        COUNT(r.rental_id) as rental_count,
        COUNT(DISTINCT r.customer_id) as unique_customers,
        SUM(r.rental_fee + r.late_fee) as genre_revenue
    FROM rentals r
    JOIN stores s ON r.store_id = s.store_id
    JOIN movies m ON r.movie_id = m.movie_id
    GROUP BY s.store_id, s.store_name, m.genre
)
SELECT 
    store_name,
    genre,
    rental_count,
    unique_customers,
    genre_revenue,
    ROUND(genre_revenue * 1.0 / rental_count, 2) as avg_value_per_rental,
    RANK() OVER (PARTITION BY store_id ORDER BY genre_revenue DESC) as revenue_rank,
    RANK() OVER (PARTITION BY store_id ORDER BY rental_count DESC) as popularity_rank,
    ROUND(
        genre_revenue * 100.0 / SUM(genre_revenue) OVER (PARTITION BY store_id),
        2
    ) as store_genre_share
FROM store_genre_stats
WHERE rental_count > 0
ORDER BY store_name, revenue_rank;