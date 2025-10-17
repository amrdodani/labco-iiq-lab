CREATE DATABASE lab_hr;
USE lab_hr;

CREATE TABLE employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(30),
    last_name VARCHAR(30),
    username VARCHAR(30),
    department VARCHAR(30),
    title VARCHAR(50),
    email VARCHAR(100)
);

INSERT INTO employees (first_name, last_name, username, department, title, email)
VALUES ('Alice', 'Smith', 'asmith', 'Engineering', 'DevOps Engineer', 'alice.smith@labco.com'),
       ('Bob', 'Jones', 'bjones', 'Sales', 'Sales Manager', 'bob.jones@labco.com'),
       ('Carol', 'Tan', 'ctan', 'Finance', 'Accountant', 'carol.tan@labco.com');
-- add 10+ more rows for realism
