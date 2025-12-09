-- Drop tables if they exist (clean start)
DROP TABLE IF EXISTS rentals;
DROP TABLE IF EXISTS dates;
DROP TABLE IF EXISTS movies;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS stores;

-- Create dimension tables
CREATE TABLE dates (
    date_id INTEGER PRIMARY KEY,
    full_date DATE NOT NULL,
    day INTEGER,
    month INTEGER,
    quarter INTEGER,
    year INTEGER
);

CREATE TABLE movies (
    movie_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    genre TEXT,
    release_year INTEGER,
    rating TEXT
);

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    city TEXT,
    state TEXT,
    join_date DATE
);

CREATE TABLE stores (
    store_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    city TEXT,
    state TEXT
);

-- Create fact table
CREATE TABLE rentals (
    rental_id INTEGER PRIMARY KEY,
    date_id INTEGER,
    movie_id INTEGER,
    customer_id INTEGER,
    store_id INTEGER,
    rental_fee DECIMAL(5,2),
    return_date DATE,
    late_fee DECIMAL(5,2),
    FOREIGN KEY (date_id) REFERENCES dates(date_id),
    FOREIGN KEY (movie_id) REFERENCES movies(movie_id),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id)
);

-- Create indexes for performance
CREATE INDEX idx_rentals_date ON rentals(date_id);
CREATE INDEX idx_rentals_movie ON rentals(movie_id);
CREATE INDEX idx_rentals_customer ON rentals(customer_id);
CREATE INDEX idx_rentals_store ON rentals(store_id);
CREATE INDEX idx_rentals_rental_date ON rentals(rental_date);
CREATE INDEX idx_movies_genre ON movies(genre);
CREATE INDEX idx_customers_city ON customers(city);
CREATE INDEX idx_dates_year_month ON dates(year, month);
