USE master
GO

IF EXISTS (
	SELECT name 
		FROM sys.databases 
		WHERE NAME = 'KN303_Moskvin'
)
DROP DATABASE [KN303_Moskvin]
GO

CREATE DATABASE [KN303_Moskvin]
GO

USE [KN303_Moskvin]
GO

IF EXISTS(
  SELECT *
    FROM sys.schemas
   WHERE NAME = 'Moskvin'
) 
 DROP SCHEMA Moskvin
GO

CREATE SCHEMA Moskvin 
GO

CREATE TABLE [KN303_Moskvin].Moskvin.Post
(
	PostId varchar(15) NOT NULL,
	CONSTRAINT PK_PostId PRIMARY KEY(PostId)
)
GO

INSERT INTO  [KN303_Moskvin].Moskvin.Post (PostId)
	VALUES 
		('post1'),
		('post2')

CREATE TABLE [KN303_Moskvin].Moskvin.RegionName
(
	RegionNameId tinyint IDENTITY(1, 1) NOT NULL,
	RegionName varchar(25) NOT NULL,
	CONSTRAINT PK_RegionNameId PRIMARY KEY(RegionNameId)
)
GO

CREATE TABLE [KN303_Moskvin].Moskvin.Region
(
	RegionCode tinyint NOT NULL,
	RegionNameId tinyint NOT NULL,
	CONSTRAINT PK_RegionCode PRIMARY KEY(RegionCode),
	CONSTRAINT FK_RegionNameId FOREIGN KEY(RegionNameId)
		REFERENCES [KN303_Moskvin].Moskvin.RegionName
)
GO

INSERT INTO [KN303_Moskvin].Moskvin.RegionName(RegionName)
VALUES('Свердловская обл.'), ('Челябинская обл.'), ('Московская обл.')


INSERT INTO [KN303_Moskvin].Moskvin.Region(RegionCode, RegionNameId)
	VALUES 
		(96, 1), 
		(77, 1),
		(196, 1),
		(74, 2),
		(174, 2),
		(90, 3)

SELECT RegionCode, RegionName.RegionName FROM [KN303_Moskvin].Moskvin.Region Inner Join [KN303_Moskvin].Moskvin.RegionName on 
[KN303_Moskvin].Moskvin.RegionName.RegionNameId = [KN303_Moskvin].Moskvin.Region.RegionNameId GROUP BY RegionCode, RegionName.RegionName

CREATE TABLE [KN303_Moskvin].Moskvin.PostCrossing
(
	CrossingId varchar(15) NOT NULL,
	CrossingPostId varchar(15) NOT NULL,
	AutomobileNumber varchar(9) NOT NULL,
	Direction varchar(3) NOT NULL,
	CrossingTime datetime2 NOT NULL,
	RegionCode AS CAST(SUBSTRING(AutomobileNumber, 7, 3) AS tinyint) PERSISTED NOT NULL,
	CONSTRAINT PK_CrossingId PRIMARY KEY(CrossingId),
	CONSTRAINT FK_CrossingPostId FOREIGN KEY(CrossingPostId)
		REFERENCES [KN303_Moskvin].Moskvin.Post,
	CONSTRAINT FK_RegionCode FOREIGN KEY(RegionCode)
		REFERENCES [KN303_Moskvin].Moskvin.Region,
	CHECK (UPPER(AutomobileNumber) LIKE '[АВЕКМНОРСТУХABEKMHOPCTYX][1-9][0-9][0-9][АВЕКМНОРСТУХABEKMHOPCTYX][АВЕКМНОРСТУХABEKMHOPCTYX][0-9][0-9]' OR 
		   UPPER(AutomobileNumber) LIKE '[АВЕКМНОРСТУХABEKMHOPCTYX][1-9][0-9][0-9][АВЕКМНОРСТУХABEKMHOPCTYX][АВЕКМНОРСТУХABEKMHOPCTYX][127][0-9][0-9]'),
	CHECK (Direction = 'In' or Direction = 'Out')
)
GO

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing
-- check number tests
-- should raise 
INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(1, 'post1', 'Q123QQ96', 'In', GETDATE()), -- wrong letter
		(2, 'post1', 'q123qq96', 'In', GETDATE()), -- wrong letter lower case
		(3, 'post1', 'A000BC96', 'In', GETDATE()), -- number starts with 0
		(4, 'post1' , 'A100BC300', 'In', GETDATE()), -- region starts with 3
		(5, 'post1','bbbbbbbb', 'In', GETDATE()) -- not a number
GO

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing
GO

-- should pass
INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(1, 'post1', 'A123AA96', 'In', GETDATE()), -- just a number
		(2, 'post1', 'B123AA196', 'In', GETDATE()) -- number with 3 chars on region
GO

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing
GO

-- Check direction tests
-- Should raise
INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(1, 'post1', 'A123AA96', 'On', GETDATE()), -- When not valid direction/word
		(2, 'post1', 'B123AA196', '123', GETDATE()), -- When not valid direction/number
		(3, 'post1', 'C123AAA96', 'in', GETDATE()) -- When lower case in
GO

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing
GO

-- Should pass
INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(1, 'post1', 'A123AA96', 'In', GETDATE()), -- When valid In
		(2, 'post1', 'A123AB96', 'Out', GETDATE()) -- When valid Out
GO

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing


SELECT RegionCode FROM [KN303_Moskvin].Moskvin.PostCrossing
GO

CREATE TRIGGER IncorrectCrossingTrigger 
	ON [KN303_Moskvin].Moskvin.PostCrossing 
	FOR INSERT AS 
		IF UPDATE(Direction)
			BEGIN
				IF EXISTS(SELECT * FROM INSERTED inserted WHERE Direction = 
								(
									SELECT TOP(1) Direction 
									FROM [KN303_Moskvin].Moskvin.PostCrossing 
									WHERE AutomobileNumber = inserted.AutomobileNumber 
									AND CrossingId != inserted.CrossingId
									ORDER BY CrossingTime DESC
								))
					BEGIN
						ROLLBACK TRANSACTION
						PRINT('Нельзя проходить посты в одном и том же направлении подряд.')
					END
			END
GO

-- IncorrectCrossingTrigger tests
INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(1, 'post1', 'A123AA96', 'In', '2021-12-11 05:00:00')
GO

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(2, 'post1', 'A123AA96', 'In', '2021-12-11 06:00:00')
GO

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing
GO

DROP TRIGGER TooFastCrossingTrigger
GO

CREATE TRIGGER TooFastCrossingTrigger 
	ON [KN303_Moskvin].Moskvin.PostCrossing 
	AFTER INSERT AS 
			BEGIN
				DECLARE @TimeoutBetweenCrossing as smallint = 5
				DECLARE
				@Id varchar(15),
				@Number varchar(9),
				@CrossingTime datetime2
				SET NOCOUNT ON;
				SELECT 
				@Id = inserted.CrossingId,
				@Number = inserted.AutomobileNumber,
				@CrossingTime = inserted.CrossingTime
				FROM Inserted

				IF (ABS(DATEDIFF(minute, (SELECT MAX(CrossingTime) 
						  FROM [KN303_Moskvin].Moskvin.PostCrossing
						  WHERE CrossingId != @Id 
						  AND AutomobileNumber = @Number),  @CrossingTime)) < @TimeoutBetweenCrossing)
				BEGIN
					ROLLBACK TRANSACTION
					PRINT('Слишком частое пересечение постов. Разница должна быть: ' + CAST(@TimeoutBetweenCrossing as varchar) + ' минут')
				END
			END
GO

-- TooFastCrossingTrigger tests
-- Should raise
DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(1, 'post1', 'A123AA96', 'In', '2021-12-11 05:00:00')
GO

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES
		(2, 'post1', 'A123AA96', 'Out', '2021-12-11 05:06:00')
GO

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing

DROP VIEW LocalAutomobiles
GO
-- Местные машины
CREATE VIEW LocalAutomobiles AS
(SELECT f1.AutomobileNumber AS [Номер], f1.CrossingTime AS [Время выезда], f2.CrossingTime AS [Время въезда], r.RegionName as [Название региона]
	FROM [KN303_Moskvin].Moskvin.PostCrossing f1
		INNER JOIN [KN303_Moskvin].Moskvin.PostCrossing f2
		ON (f1.AutomobileNumber = f2.AutomobileNumber 
			AND f1.Direction = 'Out' AND f2.Direction = 'In'
			AND f2.CrossingTime = (SELECT MIN(CrossingTime) 
								   FROM [KN303_Moskvin].Moskvin.PostCrossing 
								   WHERE CrossingTime > f1.CrossingTime))
		INNER JOIN (SELECT r1.RegionCode, r2.RegionName FROM [KN303_Moskvin].Moskvin.Region r1
					INNER JOIN [KN303_Moskvin].Moskvin.RegionName r2
					ON r1.RegionNameId = r2.RegionNameId
					GROUP BY r1.RegionCode, r2.RegionName) r ON f1.RegionCode = r.RegionCode
WHERE r.RegionName = 'Свердловская обл.'
GROUP BY  f1.AutomobileNumber, f1.CrossingTime, f2.CrossingTime, r.RegionName)
GO

SELECT * FROM LocalAutomobiles

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing
SELEct * FROM [KN303_Moskvin].Moskvin.PostCrossing

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
VALUES
	(1, 'post1', 'A123AA96', 'Out', '2021-12-11 05:00:00'),
	(2, 'post1', 'A123AA96', 'In', '2021-12-11 08:15:00')
GO

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
VALUES
	(3, 'post1', 'A123AA96', 'Out', '2021-12-11 09:20:00')
GO

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
VALUES
	(4, 'post1', 'A123AA96', 'In', '2021-12-11 10:20:00')
GO

DROP VIEW TranzitAutomobiles
-- Транзитные машины
CREATE VIEW TranzitAutomobiles AS
(SELECT f1.AutomobileNumber AS [Номер], f1.CrossingTime AS [Время въезда], f2.CrossingTime AS [Время выезда], r.RegionName as [Название региона]
	FROM [KN303_Moskvin].Moskvin.PostCrossing f1
		INNER JOIN [KN303_Moskvin].Moskvin.PostCrossing f2
		ON (f1.AutomobileNumber = f2.AutomobileNumber 
			AND f1.Direction = 'In' AND f2.Direction = 'Out'
			AND f1.CrossingPostId != f2.CrossingPostId
			AND f2.CrossingTime = (SELECT MIN(CrossingTime) 
								   FROM [KN303_Moskvin].Moskvin.PostCrossing 
								   WHERE CrossingTime > f1.CrossingTime))
		INNER JOIN (SELECT r1.RegionCode, r2.RegionName FROM [KN303_Moskvin].Moskvin.Region r1
					INNER JOIN [KN303_Moskvin].Moskvin.RegionName r2
					ON r1.RegionNameId = r2.RegionNameId
					GROUP BY r1.RegionCode, r2.RegionName) r ON f1.RegionCode = r.RegionCode
WHERE r.RegionName != 'Свердловская обл.'
GROUP BY  f1.AutomobileNumber, f1.CrossingTime, f2.CrossingTime, r.RegionName)

DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing


INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
VALUES
	(1, 'post1', 'A123AA74', 'In', '2021-12-11 09:00:00'),
	(2, 'post2', 'A123AA74', 'Out', '2021-12-11 09:20:00')
	
GO

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing(CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
VALUES
	(3, 'post2', 'A123AA74', 'In', '2021-12-11 09:40:00'),
	(4, 'post3', 'A123AA74', 'Out', '2021-12-11 10:00:00')
GO

SELECT * FROM TranzitAutomobiles

-- Иногородние машины
DROP VIEW NonresidentAutomobile

CREATE VIEW NonresidentAutomobile AS
(SELECT f1.AutomobileNumber AS [Номер], f1.CrossingTime AS [Время выезда], f2.CrossingTime AS [Время въезда], r.RegionName as [Название региона]
	FROM [KN303_Moskvin].Moskvin.PostCrossing f1
		INNER JOIN [KN303_Moskvin].Moskvin.PostCrossing f2
		ON (f1.AutomobileNumber = f2.AutomobileNumber 
			AND f1.Direction = 'In' AND f2.Direction = 'Out'
			AND f1.CrossingTime < f2.CrossingTime
			AND f1.CrossingPostId = f2.CrossingPostId
			AND f2.CrossingTime = (SELECT MIN(CrossingTime) 
								   FROM [KN303_Moskvin].Moskvin.PostCrossing 
								   WHERE CrossingTime > f1.CrossingTime))
		INNER JOIN (SELECT r1.RegionCode, r2.RegionName FROM [KN303_Moskvin].Moskvin.Region r1
					INNER JOIN [KN303_Moskvin].Moskvin.RegionName r2
					ON r1.RegionNameId = r2.RegionNameId
					GROUP BY r1.RegionCode, r2.RegionName) r ON f1.RegionCode = r.RegionCode
GROUP BY  f1.AutomobileNumber, f1.CrossingTime, f2.CrossingTime, r.RegionName)

SELECT * FROM NonresidentAutomobile
INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing (CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES 
		('10', 'post1', 'A123AA74', 'Out', '2022-12-08 07:00:00')
GO
