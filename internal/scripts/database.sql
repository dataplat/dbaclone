SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL Serializable
GO
BEGIN TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Clone]'
GO
CREATE TABLE [dbo].[Clone]
(
[CloneID] [int] NOT NULL IDENTITY(1, 1),
[ImageID] [int] NOT NULL,
[HostID] [int] NOT NULL,
[CloneLocation] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AccessPath] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SqlInstance] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DatabaseName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsEnabled] [bit] NOT NULL CONSTRAINT [DF_Clone_IsEnabled] DEFAULT ((1))
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK__Clone] on [dbo].[Clone]'
GO
ALTER TABLE [dbo].[Clone] ADD CONSTRAINT [PK__Clone] PRIMARY KEY CLUSTERED  ([CloneID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Clone_GetAll]'
GO
CREATE PROCEDURE [dbo].[Clone_GetAll]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT CloneID,
		   ImageID,
		   HostID,
		   CloneLocation,
		   AccessPath,
		   SqlInstance,
		   DatabaseName,
		   IsEnabled
	FROM dbo.Clone;
END;

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Image]'
GO
CREATE TABLE [dbo].[Image]
(
[ImageID] [int] NOT NULL IDENTITY(1, 1),
[ImageName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ImageLocation] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SizeMB] [int] NOT NULL,
[DatabaseName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DatabaseTimestamp] [datetime] NOT NULL,
[CreatedOn] [datetime] NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_Image] on [dbo].[Image]'
GO
ALTER TABLE [dbo].[Image] ADD CONSTRAINT [PK_Image] PRIMARY KEY CLUSTERED  ([ImageID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Image_GetAll]'
GO
CREATE PROCEDURE [dbo].[Image_GetAll]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT ImageID,
		   ImageName,
		   ImageLocation,
		   SizeMB,
		   DatabaseName,
		   DatabaseTimestamp,
		   CreatedOn
	FROM dbo.Image;
END;

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Host]'
GO
CREATE TABLE [dbo].[Host]
(
[HostID] [int] NOT NULL IDENTITY(1, 1),
[HostName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IPAddress] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FQDN] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK__Host] on [dbo].[Host]'
GO
ALTER TABLE [dbo].[Host] ADD CONSTRAINT [PK__Host] PRIMARY KEY CLUSTERED  ([HostID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Host_GetAll]'
GO
CREATE PROCEDURE [dbo].[Host_GetAll]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT HostID,
		   HostName,
		   IPAddress,
		   FQDN
	FROM dbo.Host;
END;

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Clone_New]'
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
	@CloneID	   INT OUTPUT,
	@ImageID	   INT,
	@HostID		   INT,
	@CloneLocation VARCHAR(255),
	@AccessPath	   VARCHAR(255),
	@SqlInstance   VARCHAR(50),
	@DatabaseName  VARCHAR(100),
	@IsEnabled	   BIT = 1
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Host_New]'
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
	@HostID	   INT OUTPUT,
	@HostName  VARCHAR(100),
	@IPAddress VARCHAR(20),
	@FQDN	   VARCHAR(255)
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [dbo].[Image_New]'
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
	@ImageID		   INT OUTPUT,
	@ImageName		   VARCHAR(100),
	@ImageLocation	   VARCHAR(255),
	@SizeMB			   INT,
	@DatabaseName	   VARCHAR(100),
	@DatabaseTimestamp DATETIME
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [dbo].[Clone]'
GO
ALTER TABLE [dbo].[Clone] ADD CONSTRAINT [FK_Clone_Image] FOREIGN KEY ([ImageID]) REFERENCES [dbo].[Image] ([ImageID])
GO
ALTER TABLE [dbo].[Clone] ADD CONSTRAINT [FK_Clone_Host] FOREIGN KEY ([HostID]) REFERENCES [dbo].[Host] ([HostID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
COMMIT TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END
GO
