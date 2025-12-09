-- 1. Rentals per store (last 90 days)
WITH last_90_days AS (
    SELECT date_id 
    FROM dates 
    WHERE full_date >= DATE('now', '-90 days')
)
SELECT 
    s.store_name,
    s.city as store_city,
    s.state as store_state,
    COUNT(r.rental_id) as rental_count,
    SUM(r.rental_fee + r.late_fee) as total_revenue,
    ROUND(AVG(r.rental_fee + r.late_fee), 2) as avg_transaction_value
FROM rentals r
JOIN stores s ON r.store_id = s.store_id
JOIN last_90_days d ON r.date_id = d.date_id
GROUP BY s.store_id, s.store_name, s.city, s.state
ORDER BY rental_count DESC;

-- 2. Top 5 movies by rental count (Year-to-Date)
SELECT 
    m.title,
    m.genre,
    m.rating,
    COUNT(r.rental_id) as rental_count,
    SUM(r.rental_fee + r.late_fee) as total_revenue,
    ROUND(AVG(r.rental_fee + r.late_fee), 2) as avg_rental_value
FROM rentals r
JOIN movies m ON r.movie_id = m.movie_id
JOIN dates d ON r.date_id = d.date_id
WHERE d.year = 2024
GROUP BY m.movie_id, m.title, m.genre, m.rating
ORDER BY rental_count DESC
LIMIT 5;

-- 3. Revenue by genre (monthly roll-up)
SELECT 
    m.genre,
    d.year,
    d.month,
    COUNT(r.rental_id) as rental_count,
    SUM(r.rental_fee) as rental_revenue,
    SUM(r.late_fee) as late_fee_revenue,
    SUM(r.rental_fee + r.late_fee) as total_revenue,
    ROUND(AVG(r.rental_fee + r.late_fee), 2) as avg_transaction_value
FROM rentals r
JOIN movies m ON r.movie_id = m.movie_id
JOIN dates d ON r.date_id = d.date_id
GROUP BY m.genre, d.year, d.month
ORDER BY d.year DESC, d.month DESC, total_revenue DESC;

-- 4. Active customers per store (last 60 days)
SELECT 
    s.store_name,
    s.city,
    s.state,
    COUNT(DISTINCT r.customer_id) as active_customers,
    COUNT(r.rental_id) as rental_count,
    SUM(r.rental_fee + r.late_fee) as total_revenue
FROM rentals r
JOIN stores s ON r.store_id = s.store_id
JOIN dates d ON r.date_id = d.date_id
WHERE d.full_date >= DATE('now', '-60 days')
GROUP BY s.store_id, s.store_name, s.city, s.state
ORDER BY active_customers DESC;

-- 5. Late returns per store
SELECT 
    s.store_name,
    s.city,
    COUNT(CASE WHEN r.return_date IS NOT NULL THEN 1 END) as total_returns,
    COUNT(CASE WHEN r.late_fee > 0 THEN 1 END) as late_returns,
    ROUND(
        COUNT(CASE WHEN r.late_fee > 0 THEN 1 END) * 100.0 / 
        NULLIF(COUNT(CASE WHEN r.return_date IS NOT NULL THEN 1 END), 0),
        2
    ) as late_return_percentage,
    SUM(r.late_fee) as total_late_fees,
    ROUND(AVG(r.late_fee), 2) as avg_late_fee
FROM rentals r
JOIN stores s ON r.store_id = s.store_id
WHERE r.return_date IS NOT NULL
GROUP BY s.store_id, s.store_name, s.city
ORDER BY late_return_percentage DESC;

-- 6. Average rental fee per genre
SELECT 
    m.genre,
    COUNT(r.rental_id) as rental_count,
    ROUND(AVG(r.rental_fee), 2) as avg_rental_fee,
    ROUND(AVG(r.late_fee), 2) as avg_late_fee,
    ROUND(AVG(r.rental_fee + r.late_fee), 2) as avg_total_fee,
    ROUND(SUM(r.rental_fee + r.late_fee), 2) as total_revenue
FROM rentals r
JOIN movies m ON r.movie_id = m.movie_id
GROUP BY m.genre
HAVING rental_count > 0
ORDER BY total_revenue DESC;

-- 7. Monthly revenue trend with running total
WITH monthly_revenue AS (
    SELECT 
        d.year,
        d.month,
        COUNT(r.rental_id) as rental_count,
        SUM(r.rental_fee + r.late_fee) as monthly_revenue
    FROM rentals r
    JOIN dates d ON r.date_id = d.date_id
    GROUP BY d.year, d.month
)
SELECT 
    year,
    month,
    rental_count,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        ORDER BY year, month 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_total,
    ROUND(
        monthly_revenue * 100.0 / SUM(monthly_revenue) OVER (),
        2
    ) as percentage_of_total,
    ROUND(
        monthly_revenue * 100.0 / LAG(monthly_revenue, 1, monthly_revenue) OVER (ORDER BY year, month),
        2
    ) as month_over_month_change
FROM monthly_revenue
ORDER BY year, month;