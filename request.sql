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
VALUES('������������ ���.'), ('����������� ���.'), ('���������� ���.')


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
	CHECK (AutomobileNumber LIKE '[ABCEKMOPTH][1-9][0-9][0-9][ABCEKMOPTH][ABCEKMOPTH][0-9][0-9]' OR 
		   AutomobileNumber LIKE '[ABCEKMOPTH][1-9][0-9][0-9][ABCEKMOPTH][ABCEKMOPTH][127][0-9][0-9]'),
	CHECK (Direction = 'In' or Direction = 'Out')
)
GO

SELECT RegionCode FROM [KN303_Moskvin].Moskvin.PostCrossing

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
						PRINT('������ ������ ���� � ����� ����������� ��� ���� ������.')
					END
			END
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

				SELECT DATEDIFF(minute, (SELECT MAX(CrossingTime) 
						  FROM [KN303_Moskvin].Moskvin.PostCrossing
						  WHERE CrossingId != @Id 
						  AND AutomobileNumber = @Number),  @CrossingTime)
				IF (DATEDIFF(minute, (SELECT MAX(CrossingTime) 
						  FROM [KN303_Moskvin].Moskvin.PostCrossing
						  WHERE CrossingId != @Id 
						  AND AutomobileNumber = @Number),  @CrossingTime) < @TimeoutBetweenCrossing)
				BEGIN
					ROLLBACK TRANSACTION
					PRINT('������� ������ ����������� ������. ������� ������ ����: ' + CAST(@TimeoutBetweenCrossing as varchar) + ' �����')
				END
			END
GO

INSERT INTO [KN303_Moskvin].Moskvin.PostCrossing (CrossingId, CrossingPostId, AutomobileNumber, Direction, CrossingTime)
	VALUES 
		('qqq3q44weq4', 'post2', 'A123AA196', 'In', '2007-05-09 00:36:00')
GO

SELECT DATEDIFF(minute,      '2005-12-31 23:59:59.9999999', '2006-01-01 00:00:00.0000000');
DELETE FROM [KN303_Moskvin].Moskvin.PostCrossing
SELECT * FROM  [KN303_Moskvin].Moskvin.PostCrossing

DROP VIEW LocalAutomobiles
CREATE VIEW LocalAutomobiles AS
SELECT AutomobileNumber as [�����] FROM [KN303_Moskvin].Moskvin.PostCrossing AS f1
WHERE CrossingTime IN
	(SELECT MIN(CrossingTime) FROM [KN303_Moskvin].Moskvin.PostCrossing AS f2
	 WHERE f1.AutomobileNumber = f2.AutomobileNumber 
	 AND Direction = 'Out'
	 AND CrossingTime < (SELECT MAX(CrossingTime) FROM [KN303_Moskvin].Moskvin.PostCrossing AS f3
						 WHERE f1.AutomobileNumber = f3.AutomobileNumber 
						 AND Direction = 'In'))
	GROUP BY AutomobileNumber, f1.CrossingTime

SELECT f1.AutomobileNumber AS [�����], f3.R AS [�������� �������], MIN(f1.CrossingTime) AS [����� ������], MAX(f2.CrossingTime) AS [����� ������]
	FROM [KN303_Moskvin].Moskvin.PostCrossing f1
		INNER JOIN [KN303_Moskvin].Moskvin.PostCrossing f2
		ON (f1.AutomobileNumber = f2.AutomobileNumber 
			AND f1.Direction = 'Out' AND f2.Direction = 'In'
			AND f1.CrossingTime < f2.CrossingTime
			AND CAST(f1.CrossingTime AS DATE) = '2007-05-09')
		INNER JOIN [KN303_Moskvin].Moskvin.RegionName f3 ON 
		f1.RegionCode = f3.RegionNameId
GROUP BY  f1.AutomobileNumber, f1.CrossingTime, f2.CrossingTime, f3.RegionName

SELECT RegionCode, RegionName.RegionName FROM [KN303_Moskvin].Moskvin.Region Inner Join [KN303_Moskvin].Moskvin.RegionName on 
[KN303_Moskvin].Moskvin.RegionName.RegionNameId = [KN303_Moskvin].Moskvin.Region.RegionNameId GROUP BY RegionCode, RegionName.RegionName
SELECT * FROM Tranzit
