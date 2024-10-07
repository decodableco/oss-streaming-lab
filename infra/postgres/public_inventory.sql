SET search_path TO inventory;

-- remove related sample data that ships with dbz image
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS order_lines CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- customers
CREATE TABLE customers (
  id SERIAL NOT NULL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  is_test_account BOOLEAN NOT NULL
);

ALTER SEQUENCE customers_id_seq RESTART WITH 1001;
ALTER TABLE customers REPLICA IDENTITY FULL;

INSERT INTO customers
VALUES (default, 'Sally', 'Thomas', 'sally.thomas@acme.com', FALSE),
       (default, 'George', 'Bailey', 'gbailey@foobar.com', FALSE),
       (default, 'Edward', 'Walker', 'ed@walker.com', FALSE),
       (default, 'Aidan', 'Barrett', 'aidan@example.com', TRUE),
       (default, 'Anne', 'Kretchmar', 'annek@noanswer.org', TRUE),
       (default, 'Melissa', 'Cole', 'melissa@example.com', FALSE),
       (default, 'Rosalie', 'Stewart', 'rosalie@example.com', FALSE);

-- addresses
CREATE TABLE addresses (
  id SERIAL NOT NULL PRIMARY KEY,
  customer_id INTEGER NOT NULL UNIQUE REFERENCES customers(id),
  line_1 VARCHAR(255) NOT NULL,
  line_2 VARCHAR(255),
  city VARCHAR(255) NOT NULL,
  state VARCHAR(255) NOT NULL,
  zip_code VARCHAR(255) NOT NULL,
  country VARCHAR(255) NOT NULL
);
ALTER SEQUENCE addresses_id_seq RESTART WITH 1000001;
ALTER TABLE addresses REPLICA IDENTITY FULL;

INSERT INTO addresses
VALUES (default, 1001, '366 Hall Street', NULL, 'Las Vegas', 'Nevada', '89119', 'US'),
       (default, 1002, '2263 New York Avenue', NULL, 'Woodland Hills', 'California', '91303', 'US'),
       (default, 1003, '746 Reynolds Alley', NULL, 'Los Angeles', 'California', '90014', 'US'),
       (default, 1004, '1004 School House Road', NULL, 'Jackson', 'Mississippi', '39201', 'US');

-- products
CREATE TABLE products (
  id SERIAL NOT NULL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description VARCHAR(512),
  weight FLOAT,
  category VARCHAR(255) NOT NULL
);
ALTER SEQUENCE products_id_seq RESTART WITH 101;
ALTER TABLE products REPLICA IDENTITY FULL;

INSERT INTO products
VALUES (default, 'scooter', 'Small 2-wheel scooter', 3.14, 'mobility'),
       (default, 'car battery', '12V car battery', 8.1, 'mobility'),
       (default, '12-pack drill bits', '12-pack of drill bits with sizes ranging from #40 to #3', 0.8, 'home improvement'),
       (default, 'hammer', '12oz carpenter''s hammer', 0.75, 'home improvement'),
       (default, 'hammer', '14oz carpenter''s hammer', 0.875, 'home improvement'),
       (default, 'hammer', '16oz carpenter''s hammer', 1.0, 'home improvement'),
       (default, 'rocks', 'box of assorted rocks', 5.3, 'outdoor'),
       (default, 'tent', 'three-person tent', 105.0, 'outdoor'),
       (default, 'jacket', 'water resistent black wind breaker', 0.1, 'fashion'),
       (default, 'spare tire', '24 inch spare tire', 22.2, 'mobility');

-- purchase orders
CREATE TABLE purchase_orders (
  id SERIAL NOT NULL PRIMARY KEY,
  order_date DATE NOT NULL,
  purchaser_id INTEGER NOT NULL,
  FOREIGN KEY (purchaser_id) REFERENCES customers(id)
);
ALTER SEQUENCE purchase_orders_id_seq RESTART WITH 10001;
ALTER TABLE purchase_orders REPLICA IDENTITY FULL;

INSERT INTO purchase_orders
VALUES (default, '2024-01-16', 1001),
       (default, '2024-01-17', 1002),
       (default, '2024-02-19', 1002),
       (default, '2024-02-11', 1004),
       (default, '2024-01-13', 1005),
       (default, '2024-03-17', 1006);

-- order lines
CREATE TABLE order_lines (
  id SERIAL NOT NULL PRIMARY KEY,
  order_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  price NUMERIC(8, 2) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES purchase_orders(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
ALTER SEQUENCE order_lines_id_seq RESTART WITH 100001;
ALTER TABLE order_lines REPLICA IDENTITY FULL;

INSERT INTO order_lines
VALUES (default, 10001, 102, 1, 39.99),
       (default, 10001, 105, 2, 129.99),
       (default, 10002, 106, 1, 29.49),
       (default, 10002, 107, 3, 49.49),
       (default, 10002, 103, 1, 19.49),
       (default, 10003, 101, 4, 219.99);

-- reviews
CREATE TABLE inventory.review (
    id SERIAL NOT NULL PRIMARY KEY,
    item_id VARCHAR(255) NOT NULL,
    review_text text 
);

CREATE SEQUENCE public.review_id_seq increment 50 START 26 MINVALUE 1;
ALTER TABLE inventory.review REPLICA IDENTITY FULL;

INSERT INTO inventory.review(id,item_id,review_text) VALUES 
        (1,'B01N0TQ0OH','work great. use a new one every month'),
        (2,'B07DD2DMXB','Little on the thin side'),
        (3,'B082W3Z9YK','Quick delivery, fixed the issue!'),
        (4,'B078W2BJY8','I wasn''t sure whether these were worth it or not, given the cost compared to the original branded filters.<br /><br />I can happily report that these are a great value and work every bit as good as the original. If you are on the fence worrying whether these are worth it- I can assure you they are.'),
        (5,'B08C9LPCQV','Easy to install got the product expected to receive'),
        (6,'B08D6RFV6D','After buying this ice machine just 15 months ago and using it 5 times per month it’s now leaking so bad I can’t use it anymore. The company has refused to replace it!'),
        (7,'B001TH7GZA','Not the best quality'),
        (8,'B00AF7WZTM','Part came quickly and fit my LG dryer.  Thanks!'),
        (9,'B001H05AXY','Always arrive in a fast manner.  Descriptions on line are accurate and helpful'),
        (10,'B085C6C7WH','The company responded very quickly. Refunded purchase price right away. No problems at all. The unit did not work. I tried ev'),
        (11,'B01AML6LT0','Love little kitchen gadgets.  Would recommend this'),
        (12,'B09B21HWFM','but i havent had it long  a year down the road  i may change my mind and i love the blue trim  i  didnt realize it matches my  shower curtain so well as its not solid  but pretty swirls of  purples and blues and this matches it nicely  i got the first one and it was broken so i did a return and replace but  im impressed and its quiet and i like tht it has no agitator  for things to get stuck under !!'),
        (13,'B07BFGZQ65','i have a K15 and was concerned it wouldnt fit  but it was PERFECT !!!'),
        (14,'B01HIT0VMW','im excited to see how the coffee comes out  i got 2 mason jars too  so i ordered a 2nd one of these so i''ll always have 2 in the fridge  for the summer<br /><br />UPDATE:  my first cup was a bit strong  i added way too much coffee i guess but i watered it down with plenty of ice and  half and half - a little cinnamon and vanilla -  i ordered the 2nd filter and it will be here soon and i plan to have iced coffee all summer ...  definitely cutting down on the amount of coffee though !!!!!'),
        (15,'B072JXR3MW','what a great deal and it even had a little coffee scooper !!!!!!!!!  i paid this for 1 in Target  when i first got my Keurig last year !!!'),
        (16,'B00009W3HD','worked great'),
        (17,'B00EORXEUS','these are OK  a little tooo big  but they work  i had ordered Melita discs and they were so flimsy  !!'),
        (18,'B00A7ZJNHO','thin and chinsy i could even bother returning it i threw them out  - the second they touched the pot it disintegrated'),
        (19,'B016TZKU54','The filter did not fit in my Keurig K50. When closing the keurig, there was still a small gap that left the keurig slightly open. I had to hold down the keurig in order to get it to register that it was shut and allow me to select my cup size, and still had to hold it down while it was brewing. Then, the water barely flowed through the filter. Tried with a finer grind as described on the instructions. After a minute of holding it there, I had only less than half a cup of coffee. I tried again with a medium grind and still had the same issue. Decided it was not worth my hassle and to return it. Return was easy and was provided with a free return label.'),
        (20,'B08R9C3F83','This was hard to find out how to put it into the office maker. I think better instructions would have been nice. I ended up poking a hold in the bottom when I put the lid down. Now coffee grounds come out into my coffee. I would not buy this product again.'),
        (21,'B076ZRN68C','Everything is great, easy to trim to stove and counter design. Thanks'),
        (22,'B07CKYZRXH','Used in one cup pod machine.  It did the job very well coffee was good.'),
        (23,'B0745N964K','You can''t beat the price! Awesome stove and looks great!!!'),
        (24,'B003AXVADA','Good price for coffee filters.'),
        (25,'B001TJ5380','These water filters do the same job as the name brand from Samsung, but they are less expensive.');
