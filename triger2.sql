use university;
DELIMITER $$
CREATE TRIGGER before_student_insert
    BEFORE INSERT ON Students
    FOR EACH ROW
BEGIN
    IF TIMESTAMPDIFF(YEAR, NEW.birth_date, CURDATE()) < 16 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Студент должен быть старше 16 лет';
    END IF;
    
    IF TIMESTAMPDIFF(YEAR, NEW.birth_date, CURDATE()) > 70 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Студент должен быть младше 70 лет';
    END IF;
END$$
DELIMITER ;