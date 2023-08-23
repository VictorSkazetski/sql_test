--view_1
GO
CREATE VIEW view_1 AS
select locale_id, max(lst_dat) as max_time, usr_sts, count(usr_id) as qty_row
from les_usr_ath
where locale_id = 'RUSSIAN' and usr_sts = 'A' and lst_dat is not null
group by usr_id, locale_id, usr_sts;
GO
--view_2
CREATE VIEW view_2 AS
select distinct user_auth.login_id, user_auth.usr_sts, user_contact_information.last_name, user_contact_information.first_name, count(operation_code.wh_id) as count_of_wh_id
from les_usr_ath user_auth 
	left join adrmst user_contact_information on user_auth.adr_id = user_contact_information.adr_id
	left join (
		select *
		from usropr
		where wh_id = '----'
	) operation_code on user_auth.usr_id = operation_code.usr_id
where locale_id = 'RUSSIAN' and user_auth.super_usr_flg <> 1
group by  user_auth.login_id, user_auth.usr_sts, user_contact_information.last_name, user_contact_information.first_name;
GO
--view_3
CREATE VIEW view_3 AS
select adrmst.adr_id, RIGHT(adrnam,3) as adrnam, adrtyp + ' ' + last_name + ' ' + LEFT(first_name, 1) + '.' as description
from adrmst inner join (
	select (case when ISNUMERIC(adrnam) = 1 then adr_id else null end) as adr_id_temp
	from adrmst
) adrmst_temp on adrmst.adr_id = adrmst_temp.adr_id_temp;
GO
--view_4
CREATE VIEW view_4 AS
select usr_id, 
	   login_id * 2 as login_id_x2,
	   convert(varchar, DATEADD(year, 1, max(lst_dat)), 104) as lst_dat_correct, 
	   convert(varchar, DATEADD(week, -2, max(lst_logout_dte)), 105) as lst_logout_dte_correct
from les_usr_ath inner join (
	select (case when ISNUMERIC(login_id) = 1 then login_id else null end) as login_id_temp
	from les_usr_ath
) les_usr_ath_temp on les_usr_ath.login_id = les_usr_ath_temp.login_id_temp
where les_usr_ath.lst_dat is not null and lst_logout_dte is not null
group by usr_id, login_id;
GO
--veiw_5
CREATE VIEW view_5 AS
select adrmst.adr_id, last_name, first_name, max(lst_logout_dte) as lst_logout_dte
from adrmst inner join les_usr_ath on adrmst.adr_id = les_usr_ath.adr_id
where left(last_name, 1) like'[А-Еа-е]' and right(last_name, 2) not in ('ич', 'ИЧ')
group by adrmst.adr_id, last_name, first_name;

--procedure_1
go
CREATE PROCEDURE Procedure_1 @TableName nvarchar(30), @UserId int
AS
BEGIN
    DECLARE @CreateTableSQL nvarchar(max);
    DECLARE @InsertIntoTableSQL nvarchar(max);
    DECLARE @InitIsIdExistsSQL nvarchar(max);
    DECLARE @IsIdExists int;
    DECLARE @UpdateTable nvarchar(max);

    SET @CreateTableSQL = 
        N'Create table ' + @TableName + ' (
            [id] [int] NOT NULL,
            [first_name] [nvarchar](30) NULL,
            [last_name] [nvarchar](30) NULL,
            [date_action] [datetime] NULL
        );';
    SET @InsertIntoTableSQL = 
        N'insert into ' + @TableName + ' (id, first_name, last_name, date_action) 
        values (' + CAST(@UserId AS nvarchar) + N', N''tempName'', N''tempLastName'', GETDATE());';
    SET @InitIsIdExistsSQL = 
        N'select @IsIdExists = count(*)
        from ' + @TableName + 
        N' where id = ' + CAST(@UserId AS nvarchar) + N';';
    SET @UpdateTable = 
        N'update ' + @TableName + 
        N' set date_action = GETDATE() ' +
        N' where id = ' + CAST(@UserId AS nvarchar) + N';';

    EXEC sp_executesql @InitIsIdExistsSQL, N'@IsIdExists int OUTPUT', @IsIdExists OUTPUT;

    IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @TableName)
    BEGIN
        IF (@IsIdExists > 0)
        BEGIN
            EXEC sp_executesql @UpdateTable;
            PRINT N'Запись в таблице успешно обновлена';
        END
        ELSE
        BEGIN
            EXEC sp_executesql @InsertIntoTableSQL;
            PRINT N'Запись успешно добавлена в таблицу.';
        END
    END
    ELSE
    BEGIN
        EXEC sp_executesql @CreateTableSQL;
        EXEC sp_executesql @InsertIntoTableSQL;
    END
END;

go
EXEC Procedure_1 @TableName = 'B', @UserId = 1;

--procedure_2
go
CREATE PROCEDURE Procedure_2
AS
BEGIN
    BEGIN TRY
		CREATE TABLE #les_usr_ath_temp (
			usr_id nvarchar(40) NOT NULL,
			login_id nvarchar(40) NULL,
			locale_id nvarchar(20) NOT NULL,
			usr_sts nvarchar(1) NULL,
			super_usr_flg int NULL,
			adr_id nvarchar(20) NULL,
			lst_dat datetime NULL,
			lst_logout_dte datetime NULL);

		DECLARE @usr_id_temp nvarchar(40);
		DECLARE	@login_id_temp nvarchar(40);
		DECLARE	@locale_id_temp nvarchar(20);
		DECLARE	@usr_sts_temp nvarchar(1);
		DECLARE	@super_usr_flg_temp int;
		DECLARE	@adr_id_temp nvarchar(20);
		DECLARE	@lst_dat_temp datetime;
		DECLARE	@lst_logout_dte_temp datetime;
		DECLARE les_usr_ath CURSOR FOR
			SELECT *
			FROM les_usr_ath;

		OPEN les_usr_ath;

		FETCH NEXT FROM les_usr_ath 
			INTO @usr_id_temp, @login_id_temp, @locale_id_temp, @usr_sts_temp, @super_usr_flg_temp, @adr_id_temp, @lst_dat_temp, @lst_logout_dte_temp;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF TRY_CONVERT(INT, @usr_id_temp) IS NOT NULL
			BEGIN
				IF CONVERT(INT, @usr_id_temp) % 3 = 0
				BEGIN
					INSERT INTO #les_usr_ath_temp (usr_id, login_id, locale_id, usr_sts, super_usr_flg, adr_id, lst_dat, lst_logout_dte)
						VALUES (@usr_id_temp, @login_id_temp, @locale_id_temp, @usr_sts_temp, @super_usr_flg_temp, @adr_id_temp, @lst_dat_temp, @lst_logout_dte_temp);
				END;
			END;
			 
			FETCH NEXT FROM les_usr_ath 
				INTO @usr_id_temp, @login_id_temp, @locale_id_temp, @usr_sts_temp, @super_usr_flg_temp, @adr_id_temp, @lst_dat_temp, @lst_logout_dte_temp;
		END
		CLOSE les_usr_ath;
		DEALLOCATE les_usr_ath;

		SELECT * 
		FROM #les_usr_ath_temp;

		DROP TABLE #les_usr_ath_temp;
	END TRY
	BEGIN CATCH
        PRINT ERROR_MESSAGE();
    END CATCH
END
go
EXEC Procedure_2

go
--procedure_3
CREATE PROCEDURE Procedure_3
AS
BEGIN
	DECLARE @adr_id int;
	DECLARE @adrnam_cor nvarchar(40);
	DECLARE @ctry_name_cor nvarchar(20);
	DECLARE @CustomTable TABLE (
		adr_id int NOT NULL,
		adrnam_cor nvarchar(40) NULL,
		ctry_name_cor nvarchar(20) NOT NULL
	);
	DECLARE adrmst_cursor CURSOR FOR
        select CAST(SUBSTRING(adr_id, PATINDEX ('%[1-9]%' , adr_id ), len(adr_id)) as INT) as adr_id_cor,
		CASE WHEN adrnam LIKE '%[0-9]%' THEN 'numeric'
			 WHEN adrnam LIKE '%[A-Za-z]%' THEN 'letter'
			 ELSE 'other'
			 END as adrnam_cor,
		CASE WHEN ctry_name is null THEN 'BLR'
			 ELSE ctry_name 
			 END as ctry_name_cor
		from adrmst;

	OPEN adrmst_cursor;

	FETCH NEXT FROM adrmst_cursor 
			INTO @adr_id, @adrnam_cor, @ctry_name_cor;

	WHILE @@FETCH_STATUS = 0
		BEGIN
			INSERT INTO @CustomTable (adr_id, adrnam_cor, ctry_name_cor)
				VALUES (@adr_id, @adrnam_cor, @ctry_name_cor);

			FETCH NEXT FROM adrmst_cursor INTO @adr_id, @adrnam_cor, @ctry_name_cor;
		END;

	CLOSE adrmst_cursor;
	DEALLOCATE adrmst_cursor;

	SELECT * FROM @CustomTable;
END

go
EXEC Procedure_3

--table log
go
CREATE TABLE LOG (
    log_id int identity(1,1) PRIMARY KEY,
    old_value nvarchar(MAX),
    new_value nvarchar(MAX),
    user_name nvarchar(50),
    type_action nvarchar(10),
    datetime_action datetime
);

--trigger_1
go
CREATE TRIGGER trigger_1
ON les_usr_ath
AFTER INSERT, DELETE, UPDATE
AS
BEGIN
    DECLARE @NewUsr_id NVARCHAR(40);
	DECLARE @NewLogin_id NVARCHAR(40);
	DECLARE @NewLocale_id NVARCHAR(20);
	DECLARE @NewUsr_sts NVARCHAR(1);
	DECLARE @NewSuper_usr_flg int;
	DECLARE @NewAdr_id NVARCHAR(20);
	DECLARE @NewLst_dat datetime;
	DECLARE @Newlst_logout_dte datetime;
	DECLARE @UserName NVARCHAR(50);
	DECLARE @OldUsr_id NVARCHAR(40);
	DECLARE @OldLogin_id NVARCHAR(40);
	DECLARE @OldLocale_id NVARCHAR(20);
	DECLARE @OldUsr_sts NVARCHAR(1);
	DECLARE @OldSuper_usr_flg int;
	DECLARE @OldAdr_id NVARCHAR(20);
	DECLARE @OldLst_dat datetime;
	DECLARE @Oldlst_logout_dte datetime;

	SET @UserName = SYSTEM_USER;
	
    IF EXISTS (SELECT * FROM inserted)
		BEGIN
			IF EXISTS (SELECT * FROM deleted)
				BEGIN
					DECLARE updated_cursor CURSOR FOR
						SELECT i.*, d.*
						FROM inserted i
							FULL JOIN deleted d ON i.usr_id = d.usr_id;

					OPEN updated_cursor;

					FETCH NEXT FROM updated_cursor 
							INTO @NewUsr_id, 
								 @NewLogin_id, 
								 @NewLocale_id, 
								 @NewUsr_sts, 
								 @NewSuper_usr_flg, 
								 @NewAdr_id, 
								 @NewLst_dat, 
								 @Newlst_logout_dte,
								 @OldUsr_id,
								 @OldLogin_id,
								 @OldLocale_id,
								 @OldUsr_sts,
								 @OldSuper_usr_flg,
								 @OldAdr_id,
								 @OldLst_dat,
								 @Oldlst_logout_dte;

					IF @NewUsr_id IS NOT NULL AND @OldUsr_id IS NOT NULL AND @NewUsr_id <> @OldUsr_id
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldUsr_id, @NewUsr_id, @UserName, 'update', GETDATE());
						END;
					IF @NewLogin_id IS NOT NULL AND @OldLogin_id IS NOT NULL AND @NewLogin_id <> @OldLogin_id
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldLogin_id, @NewLogin_id, @UserName, 'update', GETDATE());
						END;
					IF @NewLocale_id IS NOT NULL AND @OldLocale_id IS NOT NULL AND @NewLocale_id <> @OldLocale_id
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldLocale_id, @NewLocale_id, @UserName, 'update', GETDATE());
						END;
					IF @NewUsr_sts IS NOT NULL AND @OldUsr_sts IS NOT NULL AND @NewUsr_sts <> @OldUsr_sts
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldUsr_sts, @NewUsr_sts, @UserName, 'update', GETDATE());
						END;
					IF @NewSuper_usr_flg IS NOT NULL AND @OldSuper_usr_flg IS NOT NULL AND @NewSuper_usr_flg <> @OldSuper_usr_flg
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldSuper_usr_flg, @NewSuper_usr_flg, @UserName, 'update', GETDATE());
						END;
					IF @NewAdr_id IS NOT NULL AND @OldAdr_id IS NOT NULL AND @NewAdr_id <> @OldAdr_id
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldAdr_id, @NewAdr_id, @UserName, 'update', GETDATE());
						END;
					IF @NewLst_dat IS NOT NULL AND @OldLst_dat IS NOT NULL AND @NewLst_dat <> @OldLst_dat
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldLst_dat, @NewLst_dat, @UserName, 'update', GETDATE());
						END;
					IF @Newlst_logout_dte IS NOT NULL AND @Oldlst_logout_dte IS NOT NULL AND @Newlst_logout_dte <> @Oldlst_logout_dte
						BEGIN
							INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@Oldlst_logout_dte, @Newlst_logout_dte, @UserName, 'update', GETDATE());
						END;

					CLOSE updated_cursor;
					DEALLOCATE updated_cursor;
				END
			ELSE
				BEGIN
					DECLARE inserted_cursor CURSOR FOR
						select *
						from inserted

					OPEN inserted_cursor;

					FETCH NEXT FROM inserted_cursor 
							INTO @NewUsr_id, 
								 @NewLogin_id, 
								 @NewLocale_id, 
								 @NewUsr_sts, 
								 @NewSuper_usr_flg, 
								 @NewAdr_id, 
								 @NewLst_dat, 
								 @Newlst_logout_dte;

					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @NewUsr_id, @UserName, 'insert', GETDATE());
					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @NewLogin_id, @UserName, 'insert', GETDATE());
					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @NewLocale_id, @UserName, 'insert', GETDATE());
					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @NewUsr_sts, @UserName, 'insert', GETDATE());
					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @NewSuper_usr_flg, @UserName, 'insert', GETDATE());
					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @NewAdr_id, @UserName, 'insert', GETDATE());
					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @NewLst_dat, @UserName, 'insert', GETDATE());
					INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
						VALUES (null, @Newlst_logout_dte, @UserName, 'insert', GETDATE());

					CLOSE inserted_cursor;
					DEALLOCATE inserted_cursor;
				END
		END
	ELSE
		BEGIN
			DECLARE deleted_cursor CURSOR FOR
				select *
				from deleted

			OPEN deleted_cursor;

			FETCH NEXT FROM deleted_cursor 
				INTO @OldUsr_id,
					 @OldLogin_id,
					 @OldLocale_id,
					 @OldUsr_sts,
					 @OldSuper_usr_flg,
					 @OldAdr_id,
					 @OldLst_dat,
					 @Oldlst_logout_dte;

			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@OldUsr_id, null, @UserName, 'delete', GETDATE());
			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@OldLogin_id, null, @UserName, 'delete', GETDATE());
			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@OldLocale_id, null, @UserName, 'delete', GETDATE());
			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@OldUsr_sts, null, @UserName, 'delete', GETDATE());
			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@OldSuper_usr_flg, null, @UserName, 'delete', GETDATE());
			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@OldAdr_id, null, @UserName, 'delete', GETDATE());
			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@OldLst_dat, null, @UserName, 'delete', GETDATE());
			INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
				VALUES (@Oldlst_logout_dte, null, @UserName, 'delete', GETDATE());

			CLOSE deleted_cursor;
			DEALLOCATE deleted_cursor;
    END
    
END;

GO
-- trigger_2;
CREATE TRIGGER trigger_2
ON adrmst
AFTER UPDATE
AS
BEGIN
    BEGIN TRANSACTION;
	DECLARE @NewCtry_name NVARCHAR(60);
    DECLARE @OldCtry_name NVARCHAR(60);

	IF EXISTS (SELECT * FROM inserted)
		BEGIN
			IF EXISTS (SELECT * FROM deleted)
				BEGIN
					DECLARE updated_cursor CURSOR FOR
						SELECT i.ctry_name, d.ctry_name
						FROM inserted i
							FULL JOIN deleted d ON i.adr_id = d.adr_id;

					OPEN updated_cursor;

					FETCH NEXT FROM updated_cursor 
							INTO @NewCtry_name, 
								 @OldCtry_name;

					CLOSE updated_cursor;
					DEALLOCATE updated_cursor;

					IF @NewCtry_name IS NULL
						BEGIN
							ROLLBACK;
						END
					ELSE
						BEGIN
							DECLARE @SQL NVARCHAR(MAX);

							SET @SQL = N'
								INSERT INTO Log (old_value, new_value, user_name, type_action, datetime_action)
								VALUES (@OldCtry_name, @NewCtry_name, SYSTEM_USER, ''update'', GETDATE());';

							EXEC sp_executesql @SQL,
								N'@OldCtry_name NVARCHAR(60), @NewCtry_name NVARCHAR(60)',
								@OldCtry_name, @NewCtry_name;
							
							COMMIT;
				END;
		END;
	END;
END;

GO
--scalar function_1
CREATE FUNCTION f_calc(@expression NVARCHAR(MAX))
RETURNS FLOAT
AS
BEGIN
    DECLARE @result FLOAT;
	DECLARE @Number_1 NVARCHAR(100);
	DECLARE @Number_2 NVARCHAR(100);

	if @expression LIKE '%[+]%'
		BEGIN
			SELECT @Number_1 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 1
			SELECT @Number_2 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 3

			SET @result = cast(@Number_1 as float) + cast(@Number_2 as float)
		END
	if @expression LIKE '%[-]%'
		BEGIN
			SELECT @Number_1 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 1
			SELECT @Number_2 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 3

			SET @result = cast(@Number_1 as float) - cast(@Number_2 as float)
		END
	if @expression LIKE '%[*]%'
		BEGIN
			SELECT @Number_1 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 1
			SELECT @Number_2 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 3

			SET @result = cast(@Number_1 as float) * cast(@Number_2 as float)
		END
	if @expression LIKE '%[/]%'
		BEGIN
			SELECT @Number_1 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 1
			SELECT @Number_2 = value
				FROM (
					SELECT value,
						   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS row_num -- Assign row numbers
					FROM STRING_SPLIT(@expression, ' ')
				) as t1
				WHERE row_num = 3

			SET @result = cast(@Number_1 as float) / cast(@Number_2 as float)
		END
   
	RETURN @result;
END;
GO
--scalar function_2
CREATE FUNCTION f_columnsCnt(@tableName NVARCHAR(128))
RETURNS INT
AS
BEGIN
    DECLARE @columnCount INT;

    SELECT @columnCount = COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @tableName;

    RETURN @columnCount;
END;
GO
--scalar function_3
CREATE FUNCTION f_table(@startDate DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT @startDate as date,
		   user_contact_information.last_name AS last_name,
		   user_auth.lst_logout_dte AS logout_date
    FROM les_usr_ath user_auth
    LEFT JOIN adrmst user_contact_information ON user_auth.adr_id = user_contact_information.adr_id
    WHERE user_auth.lst_logout_dte BETWEEN @startDate AND GETDATE() AND user_contact_information.last_name is not null
);
go
select *
from dbo.f_table('2020-04-02 04:59:07.060');

