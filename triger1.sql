use university;	
DELIMITER $$
CREATE TRIGGER before_class_schedule_insert
    BEFORE INSERT ON ClassSchedule
    FOR EACH ROW
BEGIN
    DECLARE conflict_count INT;
    
    SELECT COUNT(*) INTO conflict_count
    FROM ClassSchedule
    WHERE professor_id = NEW.professor_id
    AND day_of_week = NEW.day_of_week
    AND academic_year = NEW.academic_year
    AND semester = NEW.semester
    AND (
        (NEW.start_time BETWEEN start_time AND end_time) OR
        (NEW.end_time BETWEEN start_time AND end_time) OR
        (start_time BETWEEN NEW.start_time AND NEW.end_time)
    )
    AND room = NEW.room;
    
    IF conflict_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Конфликт расписания: аудитория или преподаватель уже заняты в это время';
    END IF;
END$$
DELIMITER ;