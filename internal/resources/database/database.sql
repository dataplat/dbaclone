
CREATE TABLE [dbo].[Clone]
(
	[CloneID]       [INT]           NOT NULL IDENTITY(1, 1)
	,[ImageID]       [INT]           NOT NULL
	,[HostID]        [INT]           NOT NULL
	,[CloneLocation] [VARCHAR] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[AccessPath]    [VARCHAR] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[SqlInstance]   [VARCHAR] (50)  COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[DatabaseName]  [VARCHAR] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[IsEnabled]     [BIT]           NOT NULL CONSTRAINT [DF_Clone_IsEnabled] DEFAULT ((1))
)
GO

CREATE PROCEDURE [dbo].[Clone_GetAll]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		CloneID
		,ImageID
		,HostID
		,CloneLocation
		,AccessPath
		,SqlInstance
		,DatabaseName
		,IsEnabled
	FROM
		dbo.Clone;
END;

GO

CREATE TABLE [dbo].[Image]
(
	[ImageID]           [INT]           NOT NULL IDENTITY(1, 1)
	,[ImageName]         [VARCHAR] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[ImageLocation]     [VARCHAR] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[SizeMB]            [INT]           NOT NULL
	,[DatabaseName]      [VARCHAR] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[DatabaseTimestamp] [DATETIME]      NOT NULL
	,[CreatedOn]         [DATETIME]      NOT NULL
)
GO

CREATE PROCEDURE [dbo].[Image_GetAll]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		ImageID
		,ImageName
		,ImageLocation
		,SizeMB
		,DatabaseName
		,DatabaseTimestamp
		,CreatedOn
	FROM
		dbo.Image;
END;

GO

CREATE TABLE [dbo].[Host]
(
	[HostID]    [INT]           NOT NULL IDENTITY(1, 1)
	,[HostName]  [VARCHAR] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,[IPAddress] [VARCHAR] (20)  COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	,[FQDN]      [VARCHAR] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO

CREATE PROCEDURE [dbo].[Host_GetAll]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		HostID
		,HostName
		,IPAddress
		,FQDN
	FROM
		dbo.Host;
END;

GO

/*
Description:
Procedure for adding a new clone

Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
2018-06-20	Sander Stad				Initial procedure
*/
CREATE PROCEDURE [dbo].[Clone_New]
	@CloneID	   INT OUTPUT
	,@ImageID	   INT
	,@HostID		   INT
	,@CloneLocation VARCHAR(255)
	,@AccessPath	   VARCHAR(255)
	,@SqlInstance   VARCHAR(50)
	,@DatabaseName  VARCHAR(100)
	,@IsEnabled	   BIT = 1
AS
BEGIN

	-- Set session options to make sure transactions are aborted correctly
	-- and the procedure doesn't return the count
	SET XACT_ABORT, NOCOUNT ON;

	-- Declare variables
	DECLARE @SqlCmd NVARCHAR(MAX);
	DECLARE @Params NVARCHAR(MAX);

	SET @SqlCmd
		= N'INSERT INTO dbo.Clone
		(
			ImageID,
			HostID,
			CloneLocation,
			AccessPath,
			SqlInstance,
			DatabaseName,
			IsEnabled
		)
		VALUES
		(
			@ImageID,	    -- ImageID - int
			@HostID,	    -- HostID - int
			@CloneLocation, -- CloneLocation - varchar(255)
			@AccessPath,	-- AccessPath - varchar(255)
			@SqlInstance,   -- VARCHAR(50)
			@DatabaseName,	-- VARCHAR(100)
			@IsEnabled	    -- BIT
			);

			SELECT @CloneID = SCOPE_IDENTITY();
		';

	-- Set the parameters
	SET @Params
		= N'
			@CloneID INT OUTPUT,
			@ImageID INT,
			@HostID	 INT,
			@CloneLocation VARCHAR(255),
			@AccessPath VARCHAR(255),
			@SqlInstance  VARCHAR(50),
			@DatabaseName VARCHAR(100),
			@IsEnabled	BIT
		';

	-- Execute the SQL command
	EXECUTE sp_executesql @stmnt = @SqlCmd,
						  @params = @Params,
						  @CloneID = @CloneID OUTPUT,
						  @ImageID = @ImageID,
						  @HostID = @HostID,
						  @CloneLocation = @CloneLocation,
						  @AccessPath = @AccessPath,
						  @SqlInstance = @SqlInstance,
						  @DatabaseName = @DatabaseName,
						  @IsEnabled = @IsEnabled;


END;
GO

/*
Description:
Procedure for adding a new host

Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
2018-06-20	Sander Stad				Initial procedure
*/
CREATE PROCEDURE [dbo].[Host_New]
	@HostID	   INT OUTPUT
	,@HostName  VARCHAR(100)
	,@IPAddress VARCHAR(20)
	,@FQDN	   VARCHAR(255)
AS
BEGIN

	-- Set session options to make sure transactions are aborted correctly
	-- and the procedure doesn't return the count
	SET XACT_ABORT, NOCOUNT ON;

	-- Declare variables
	DECLARE @SqlCmd NVARCHAR(MAX);
	DECLARE @Params NVARCHAR(MAX);

	SET @SqlCmd
		= N'INSERT INTO dbo.Host
			(
				HostName,
				IPAddress,
				FQDN
			)
			VALUES
			(	@HostName,	-- HostName - varchar(100)
				@IPAddress, -- IPAddress - varchar(20)
				@FQDN		-- FQDN - varchar(255)
				);

			SELECT @HostID = SCOPE_IDENTITY();
		';

	-- Set the parameters
	SET @Params = N'
			@HostID INT OUTPUT,
			@HostName  VARCHAR(100),
			@IPAddress VARCHAR(20),
			@FQDN	   VARCHAR(255)
		';

	-- Execute the SQL command
	EXECUTE sp_executesql @stmnt = @SqlCmd,
						  @params = @Params,
						  @HostID = @HostID OUTPUT,
						  @HostName = @HostName,
						  @IPAddress = @IPAddress,
						  @FQDN = @FQDN;


END;
GO

/*
Description:
Procedure for adding a new image

Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
2018-06-20	Sander Stad				Initial procedure
*/
CREATE PROCEDURE [dbo].[Image_New]
	@ImageID		   INT OUTPUT
	,@ImageName		   VARCHAR(100)
	,@ImageLocation	   VARCHAR(255)
	,@SizeMB			   INT
	,@DatabaseName	   VARCHAR(100)
	,@DatabaseTimestamp DATETIME
AS
BEGIN

	-- Set session options to make sure transactions are aborted correctly
	-- and the procedure doesn't return the count
	SET XACT_ABORT, NOCOUNT ON;

	-- Declare variables
	DECLARE @SqlCmd NVARCHAR(MAX);
	DECLARE @Params NVARCHAR(MAX);

	SET @SqlCmd
		= N'INSERT INTO dbo.Image
			(
				ImageName,
				ImageLocation,
				SizeMB,
				DatabaseName,
				DatabaseTimestamp,
				CreatedOn
			)
			VALUES
			(	@ImageName,			-- ImageName - varchar(100)
				@ImageLocation,		-- ImageLocation - varchar(255)
				@SizeMB,			-- SizeMB - int
				@DatabaseName,		-- DatabaseName - varchar(100)
				@DatabaseTimestamp, -- DatabaseTimestamp - datetime
				GETDATE()			-- CreatedOn - datetime
				);

			SELECT @ImageID = SCOPE_IDENTITY();
		';

	-- Set the parameters
	SET @Params
		= N'
			@ImageID		   INT OUTPUT,
			@ImageName		   VARCHAR(100),
			@ImageLocation	   VARCHAR(255),
			@SizeMB			   INT,
			@DatabaseName	   VARCHAR(100),
			@DatabaseTimestamp DATETIME
		';

	-- Execute the SQL command
	EXECUTE sp_executesql @stmnt = @SqlCmd,
						  @params = @Params,
						  @ImageID = @ImageID OUTPUT,
						  @ImageName = @ImageName,
						  @ImageLocation = @ImageLocation,
						  @SizeMB = @SizeMB,
						  @DatabaseName = @DatabaseName,
						  @DatabaseTimestamp = @DatabaseTimestamp;



END;
GO

