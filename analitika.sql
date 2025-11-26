USE university;

-- 1. АНАЛИЗ ИНДЕКСОВ И СТАТИСТИКИ ТАБЛИЦ
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    DATA_LENGTH / 1024 / 1024 as 'Data Size (MB)',
    INDEX_LENGTH / 1024 / 1024 as 'Index Size (MB)',
    (DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024 as 'Total Size (MB)',
    ROUND((INDEX_LENGTH / DATA_LENGTH) * 100, 2) as 'Index/Data Ratio %'
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'university'
ORDER BY TABLE_ROWS DESC;

-- 2. АНАЛИЗ ИСПОЛЬЗОВАНИЯ ИНДЕКСОВ
SELECT 
    OBJECT_TYPE,
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    COUNT_READ,
    COUNT_FETCH,
    COUNT_INSERT,
    COUNT_UPDATE,
    COUNT_DELETE
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE OBJECT_SCHEMA = 'university'
ORDER BY COUNT_READ DESC;

-- 3. ТЕСТИРОВАНИЕ ПРОИЗВОДИТЕЛЬНОСТИ ЗАПРОСОВ

-- Запрос 1: Поиск студентов по имени с измерением времени
SELECT SQL_NO_CACHE 
    student_id, first_name, last_name, email, enrollment_date
FROM Students 
WHERE last_name LIKE 'Смир%' 
AND first_name LIKE 'Ив%';

-- Запрос 2: Сложный JOIN с агрегацией
SELECT SQL_NO_CACHE 
    f.faculty_name,
    d.department_name,
    COUNT(DISTINCT p.professor_id) as professor_count,
    COUNT(DISTINCT s.student_id) as student_count,
    AVG(g.grade) as avg_grade
FROM Faculties f
LEFT JOIN Departments d ON f.faculty_id = d.faculty_id
LEFT JOIN Professors p ON d.department_id = p.department_id
LEFT JOIN Students s ON f.faculty_id = s.faculty_id
LEFT JOIN Grades g ON s.student_id = g.student_id
GROUP BY f.faculty_id, d.department_id
ORDER BY avg_grade DESC;

-- Запрос 3: Анализ загруженности преподавателей
SELECT SQL_NO_CACHE 
    p.first_name,
    p.last_name,
    d.department_name,
    COUNT(DISTINCT cs.course_id) as courses_count,
    COUNT(DISTINCT g.grade_id) as grades_count,
    COUNT(DISTINCT pp.publication_id) as publications_count
FROM Professors p
JOIN Departments d ON p.department_id = d.department_id
LEFT JOIN ClassSchedule cs ON p.professor_id = cs.professor_id
LEFT JOIN Grades g ON p.professor_id = g.professor_id
LEFT JOIN ProfessorPublications pp ON p.professor_id = pp.professor_id
GROUP BY p.professor_id
ORDER BY courses_count DESC, publications_count DESC;

-- 4. EXPLAIN АНАЛИЗ СЛОЖНЫХ ЗАПРОСОВ

-- Анализ запроса с несколькими JOIN
EXPLAIN FORMAT=JSON
SELECT 
    s.first_name,
    s.last_name,
    c.course_name,
    g.grade,
    p.first_name as professor_first_name,
    p.last_name as professor_last_name
FROM Students s
JOIN Grades g ON s.student_id = g.student_id
JOIN Courses c ON g.course_id = c.course_id
JOIN Professors p ON g.professor_id = p.professor_id
WHERE g.grade > 85
ORDER BY g.grade DESC;

-- 5. ТЕСТИРОВАНИЕ ПРОИЗВОДИТЕЛЬНОСТИ ПРИ БОЛЬШОЙ НАГРУЗКЕ

-- Создадим временную таблицу для тестирования
CREATE TEMPORARY TABLE IF NOT EXISTS performance_test AS
SELECT 
    s.student_id,
    s.first_name,
    s.last_name,
    c.course_id,
    c.course_name,
    ROUND(RAND() * 100, 1) as test_grade
FROM Students s
CROSS JOIN Courses c
LIMIT 1000;

-- Тест агрегации на большом наборе данных
SELECT SQL_NO_CACHE 
    course_name,
    COUNT(*) as student_count,
    AVG(test_grade) as avg_grade,
    MAX(test_grade) as max_grade,
    MIN(test_grade) as min_grade
FROM performance_test
GROUP BY course_name
ORDER BY avg_grade DESC;

-- 6. АНАЛИЗ ЭФФЕКТИВНОСТИ ИНДЕКСОВ

-- Проверим использование индексов для поиска
EXPLAIN 
SELECT * FROM Students 
WHERE faculty_id = 1 AND status = 'Active';

EXPLAIN 
SELECT * FROM Grades 
WHERE student_id = 1 AND academic_year = 2023;

EXPLAIN
SELECT * FROM ResourceLoans 
WHERE due_date < CURDATE() AND return_date IS NULL;

-- 7. ТЕСТИРОВАНИЕ ПРОИЗВОДИТЕЛЬНОСТИ ОБНОВЛЕНИЙ

-- Измеряем производительность обновления
SELECT SQL_NO_CACHE @start_time := NOW(6);

UPDATE Students 
SET status = 'Graduated' 
WHERE enrollment_date < '2019-09-01' 
AND status = 'Active';

SELECT 
    TIMEDIFF(NOW(6), @start_time) as update_execution_time;

-- 8. БЕНЧМАРК СЛОЖНЫХ ОТЧЕТОВ

-- Отчет: Статистика по факультетам
SELECT SQL_NO_CACHE 
    f.faculty_name,
    COUNT(DISTINCT s.student_id) as total_students,
    COUNT(DISTINCT p.professor_id) as total_professors,
    COUNT(DISTINCT c.course_id) as total_courses,
    AVG(g.grade) as average_grade,
    COUNT(DISTINCT pub.publication_id) as total_publications,
    SUM(rp.budget) as total_research_budget
FROM Faculties f
LEFT JOIN Students s ON f.faculty_id = s.faculty_id
LEFT JOIN Departments d ON f.faculty_id = d.faculty_id
LEFT JOIN Professors p ON d.department_id = p.department_id
LEFT JOIN Courses c ON d.department_id = c.department_id
LEFT JOIN Grades g ON s.student_id = g.student_id
LEFT JOIN ProfessorPublications pp ON p.professor_id = pp.professor_id
LEFT JOIN Publications pub ON pp.publication_id = pub.publication_id
LEFT JOIN Laboratories l ON d.department_id = l.department_id
LEFT JOIN ResearchProjects rp ON l.lab_id = rp.lab_id
GROUP BY f.faculty_id
ORDER BY average_grade DESC;

-- 9. АНАЛИЗ БЛОКИРОВОК И ПРОИЗВОДИТЕЛЬНОСТИ ТРАНЗАКЦИЙ

-- Тестируем конкурентный доступ
START TRANSACTION;

SELECT @loan_count := COUNT(*) 
FROM ResourceLoans 
WHERE resource_id = 1 
AND return_date IS NULL 
FOR UPDATE;

-- Имитируем обработку
SELECT SLEEP(0.1);

INSERT INTO ResourceLoans (resource_id, student_id, loan_date, due_date)
VALUES (1, 2, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY));

COMMIT;

-- 10. РЕКОМЕНДАЦИИ ПО ОПТИМИЗАЦИИ

-- Находим потенциально missing indexes
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    SEQ_IN_INDEX
FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = 'university'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

-- Анализ самых больших таблиц
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    DATA_LENGTH / 1024 / 1024 as data_mb,
    INDEX_LENGTH / 1024 / 1024 as index_mb
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'university'
ORDER BY DATA_LENGTH DESC
LIMIT 10;

-- 11. ТЕСТ ПРОИЗВОДИТЕЛЬНОСТИ С ИСПОЛЬЗОВАНИЕМ ПРОЦЕДУР

DELIMITER $$
CREATE PROCEDURE TestComplexQueryPerformance()
BEGIN
    DECLARE start_time TIMESTAMP(6);
    DECLARE end_time TIMESTAMP(6);
    
    SET start_time = NOW(6);
    
    -- Сложный аналитический запрос
    SELECT 
        f.faculty_name,
        YEAR(s.enrollment_date) as enrollment_year,
        COUNT(DISTINCT s.student_id) as students_count,
        AVG(g.grade) as avg_grade,
        COUNT(DISTINCT pub.publication_id) as publications_count
    FROM Faculties f
    JOIN Students s ON f.faculty_id = s.faculty_id
    LEFT JOIN Grades g ON s.student_id = g.student_id
    LEFT JOIN ProfessorPublications pp ON (
        SELECT professor_id FROM Professors WHERE department_id IN (
            SELECT department_id FROM Departments WHERE faculty_id = f.faculty_id
        )
    )
    LEFT JOIN Publications pub ON pp.publication_id = pub.publication_id
    WHERE s.status = 'Active'
    GROUP BY f.faculty_id, YEAR(s.enrollment_date)
    ORDER BY f.faculty_name, enrollment_year;
    
    SET end_time = NOW(6);
    
    SELECT TIMEDIFF(end_time, start_time) as execution_time;
END$$
DELIMITER ;

-- Запуск тестовой процедуры
CALL TestComplexQueryPerformance();

-- 12. ФИНАЛЬНЫЙ АНАЛИЗ ПРОИЗВОДИТЕЛЬНОСТИ

-- Сводная статистика по производительности
SELECT 
    'Query Performance Summary' as analysis_type,
    'All tests completed' as result,
    'Check execution times above' as recommendations
UNION ALL
SELECT 
    'Index Efficiency',
    CONCAT(ROUND(AVG(INDEX_LENGTH / DATA_LENGTH * 100), 2), '%'),
    'Optimal: 10-30%'
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'university' AND DATA_LENGTH > 0;