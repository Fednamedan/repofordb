SELECT 
    rp.project_name AS 'Название проекта',
    l.lab_name AS 'Лаборатория',
    d.department_name AS 'Кафедра',
    CONCAT(p.first_name, ' ', p.last_name) AS 'Руководитель проекта',
    rp.start_date AS 'Дата начала',
    rp.end_date AS 'Планируемая дата завершения',
    rp.budget AS 'Бюджет',
    rp.funding_source AS 'Источник финансирования',
    rp.status AS 'Статус',
    COUNT(DISTINCT sp.student_id) AS 'Студентов участвует',
    ROUND(SUM(sp.hours_per_week), 1) AS 'Общая нагрузка (часов/неделю)',
    ROUND(SUM(sp.stipend), 2) AS 'Общие стипендии',
    ROUND((rp.budget / NULLIF(DATEDIFF(rp.end_date, rp.start_date), 0)) * 30, 2) AS 'Бюджет в месяц',
    CASE 
        WHEN rp.end_date < CURDATE() THEN 'Просрочен'
        WHEN DATEDIFF(rp.end_date, CURDATE()) < 30 THEN 'Завершается'
        ELSE 'В работе'
    END AS 'Статус выполнения'
FROM ResearchProjects rp
JOIN Laboratories l ON rp.lab_id = l.lab_id
JOIN Departments d ON l.department_id = d.department_id
JOIN Professors p ON rp.principal_investigator_id = p.professor_id
LEFT JOIN StudentProjects sp ON rp.project_id = sp.project_id
WHERE rp.status IN ('Active', 'Planning')
GROUP BY rp.project_id
ORDER BY rp.budget DESC, 'Студентов участвует' DESC;te