-- PostgreSQL Production DDL Script for FUTO Student Result Portal
-- File: portfolio-1-database-design/01_futo_schema.sql

BEGIN;

CREATE SCHEMA IF NOT EXISTS futo_portal;
SET search_path TO futo_portal, public;

-- 1. Faculty Table
CREATE TABLE faculties (
    faculty_id SERIAL PRIMARY KEY,
    faculty_code VARCHAR(10) UNIQUE NOT NULL,
    faculty_name VARCHAR(150) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Department Table
CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    dept_code VARCHAR(10) UNIQUE NOT NULL,
    dept_name VARCHAR(150) NOT NULL,
    faculty_id INT NOT NULL REFERENCES faculties(faculty_id) ON DELETE RESTRICT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Academic Program / Student Entity
CREATE TABLE students (
    matric_no VARCHAR(12) PRIMARY KEY, -- Format e.g., 20211234567
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    dept_id INT NOT NULL REFERENCES departments(dept_id) ON DELETE RESTRICT,
    enrollment_year INT NOT NULL CHECK (enrollment_year >= 2000),
    current_level INT NOT NULL CHECK (current_level IN (100, 200, 300, 400, 500)),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'GRADUATED', 'WITHDRAWN'))
);

-- 4. Course Catalog Entity
CREATE TABLE courses (
    course_code VARCHAR(10) PRIMARY KEY, -- e.g., MTH101, EEE512
    course_title VARCHAR(150) NOT NULL,
    credit_unit INT NOT NULL CHECK (credit_unit BETWEEN 1 AND 6),
    dept_id INT NOT NULL REFERENCES departments(dept_id) ON DELETE RESTRICT,
    level INT NOT NULL CHECK (level IN (100, 200, 300, 400, 500)),
    semester INT NOT NULL CHECK (semester IN (1, 2))
);

-- 5. Course Registration Junction Entity
CREATE TABLE course_registrations (
    reg_id BIGSERIAL PRIMARY KEY,
    matric_no VARCHAR(12) NOT NULL REFERENCES students(matric_no) ON DELETE CASCADE,
    course_code VARCHAR(10) NOT NULL REFERENCES courses(course_code) ON DELETE RESTRICT,
    session VARCHAR(9) NOT NULL, -- e.g., '2025/2026'
    semester INT NOT NULL CHECK (semester IN (1, 2)),
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_student_course_session UNIQUE (matric_no, course_code, session, semester)
);

-- 6. Grade Result Entity
CREATE TABLE grade_results (
    result_id BIGSERIAL PRIMARY KEY,
    reg_id BIGINT UNIQUE NOT NULL REFERENCES course_registrations(reg_id) ON DELETE CASCADE,
    ca_score NUMERIC(5,2) DEFAULT 0.00 CHECK (ca_score BETWEEN 0.00 AND 30.00),
    exam_score NUMERIC(5,2) DEFAULT 0.00 CHECK (exam_score BETWEEN 0.00 AND 70.00),
    total_score NUMERIC(5,2) GENERATED ALWAYS AS (ca_score + exam_score) STORED,
    grade_letter CHAR(1),
    grade_point INT,
    approved_by_hod BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Auto-compute Grade Letter and Grade Point Trigger Function
CREATE OR REPLACE FUNCTION compute_futo_grade()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.total_score >= 70.00 THEN
        NEW.grade_letter := 'A'; NEW.grade_point := 5;
    ELSIF NEW.total_score >= 60.00 THEN
        NEW.grade_letter := 'B'; NEW.grade_point := 4;
    ELSIF NEW.total_score >= 50.00 THEN
        NEW.grade_letter := 'C'; NEW.grade_point := 3;
    ELSIF NEW.total_score >= 45.00 THEN
        NEW.grade_letter := 'D'; NEW.grade_point := 2;
    ELSIF NEW.total_score >= 40.00 THEN
        NEW.grade_letter := 'E'; NEW.grade_point := 1;
    ELSE
        NEW.grade_letter := 'F'; NEW.grade_point := 0;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_compute_futo_grade
BEFORE INSERT OR UPDATE ON grade_results
FOR EACH ROW EXECUTE FUNCTION compute_futo_grade();

COMMIT;
