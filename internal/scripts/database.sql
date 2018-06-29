SET NUMERIC_ROUNDABORT OFF

SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON

SET XACT_ABORT ON

SET TRANSACTION ISOLATION LEVEL Serializable

BEGIN TRANSACTION

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Dropping [dbo].[Image_New]'

IF OBJECT_ID(N'[dbo].[Image_New]', 'P') IS NOT NULL
DROP PROCEDURE [dbo].[Image_New]

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Dropping [dbo].[Host_New]'

IF OBJECT_ID(N'[dbo].[Host_New]', 'P') IS NOT NULL
DROP PROCEDURE [dbo].[Host_New]

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Dropping [dbo].[Clone_New]'

IF OBJECT_ID(N'[dbo].[Clone_New]', 'P') IS NOT NULL
DROP PROCEDURE [dbo].[Clone_New]

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating [dbo].[Clone]'

IF OBJECT_ID(N'[dbo].[Clone]', 'U') IS NULL
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

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating primary key [PK__Clone] on [dbo].[Clone]'

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'PK__Clone' AND object_id = OBJECT_ID(N'[dbo].[Clone]'))
ALTER TABLE [dbo].[Clone] ADD CONSTRAINT [PK__Clone] PRIMARY KEY CLUSTERED  ([CloneID])

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating [dbo].[Host]'

IF OBJECT_ID(N'[dbo].[Host]', 'U') IS NULL
CREATE TABLE [dbo].[Host]
(
[HostID] [int] NOT NULL IDENTITY(1, 1),
[HostName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IPAddress] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FQDN] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
)

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating primary key [PK__Host] on [dbo].[Host]'

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'PK__Host' AND object_id = OBJECT_ID(N'[dbo].[Host]'))
ALTER TABLE [dbo].[Host] ADD CONSTRAINT [PK__Host] PRIMARY KEY CLUSTERED  ([HostID])

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating [dbo].[Image]'

IF OBJECT_ID(N'[dbo].[Image]', 'U') IS NULL
CREATE TABLE [dbo].[Image]
(
[ImageID] [int] NOT NULL IDENTITY(1, 1),
[ImageLocation] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SizeMB] [int] NOT NULL,
[DatabaseName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DatabaseTimestamp] [datetime] NOT NULL,
[CreatedOn] [datetime] NOT NULL
)

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating primary key [PK_Image] on [dbo].[Image]'

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'PK_Image' AND object_id = OBJECT_ID(N'[dbo].[Image]'))
ALTER TABLE [dbo].[Image] ADD CONSTRAINT [PK_Image] PRIMARY KEY CLUSTERED  ([ImageID])

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating [dbo].[Clone_New]'

IF OBJECT_ID(N'[dbo].[Clone_New]', 'P') IS NULL
EXEC sp_executesql N'/*
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
	-- and the procedure doesn''t return the count
	SET XACT_ABORT, NOCOUNT ON;

	-- Declare variables
	DECLARE @SqlCmd NVARCHAR(MAX);
	DECLARE @Params NVARCHAR(MAX);

	SET @SqlCmd
		= N''INSERT INTO dbo.Clone
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
		'';

	-- Set the parameters
	SET @Params
		= N''
			@CloneID INT OUTPUT,
			@ImageID INT,
			@HostID	 INT,
			@CloneLocation VARCHAR(255),
			@AccessPath VARCHAR(255),
			@SqlInstance  VARCHAR(50),
			@DatabaseName VARCHAR(100),
			@IsEnabled	BIT
		'';

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


END;'

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating [dbo].[Host_New]'

IF OBJECT_ID(N'[dbo].[Host_New]', 'P') IS NULL
EXEC sp_executesql N'/*
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
	-- and the procedure doesn''t return the count
	SET XACT_ABORT, NOCOUNT ON;

	-- Declare variables
	DECLARE @SqlCmd NVARCHAR(MAX);
	DECLARE @Params NVARCHAR(MAX);

	SET @SqlCmd
		= N''INSERT INTO dbo.Host
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
		'';

	-- Set the parameters
	SET @Params = N''
			@HostID INT OUTPUT,
			@HostName  VARCHAR(100),
			@IPAddress VARCHAR(20),
			@FQDN	   VARCHAR(255)
		'';

	-- Execute the SQL command
	EXECUTE sp_executesql @stmnt = @SqlCmd,
						  @params = @Params,
						  @HostID = @HostID OUTPUT,
						  @HostName = @HostName,
						  @IPAddress = @IPAddress,
						  @FQDN = @FQDN;


END;'

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Creating [dbo].[Image_New]'

IF OBJECT_ID(N'[dbo].[Image_New]', 'P') IS NULL
EXEC sp_executesql N'/*
Description:
Procedure for adding a new image

Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
2018-06-20	Sander Stad				Initial procedure
*/
CREATE PROCEDURE [dbo].[Image_New]
	@ImageID		   INT OUTPUT,
	@ImageLocation	   VARCHAR(255),
	@SizeMB			   INT,
	@DatabaseName	   VARCHAR(100),
	@DatabaseTimestamp DATETIME
AS
BEGIN

	-- Set session options to make sure transactions are aborted correctly
	-- and the procedure doesn''t return the count
	SET XACT_ABORT, NOCOUNT ON;

	-- Declare variables
	DECLARE @SqlCmd NVARCHAR(MAX);
	DECLARE @Params NVARCHAR(MAX);

	SET @SqlCmd
		= N''INSERT INTO dbo.Image
			(
				ImageLocation,
				SizeMB,
				DatabaseName,
				DatabaseTimestamp,
				CreatedOn
			)
			VALUES
			(	@ImageLocation,		-- ImageLocation - varchar(255)
				@SizeMB,			-- SizeMB - int
				@DatabaseName,		-- DatabaseName - varchar(100)
				@DatabaseTimestamp, -- DatabaseTimestamp - datetime
				GETDATE()			-- CreatedOn - datetime
				);

			SELECT @ImageID = SCOPE_IDENTITY();
		'';

	-- Set the parameters
	SET @Params
		= N''
			@ImageID		   INT OUTPUT,
			@ImageLocation	   VARCHAR(255),
			@SizeMB			   INT,
			@DatabaseName	   VARCHAR(100),
			@DatabaseTimestamp DATETIME
		'';

	-- Execute the SQL command
	EXECUTE sp_executesql @stmnt = @SqlCmd,
						  @params = @Params,
						  @ImageID = @ImageID OUTPUT,
						  @ImageLocation = @ImageLocation,
						  @SizeMB = @SizeMB,
						  @DatabaseName = @DatabaseName,
						  @DatabaseTimestamp = @DatabaseTimestamp;



END;'

IF @@ERROR <> 0 SET NOEXEC ON

PRINT N'Adding foreign keys to [dbo].[Clone]'

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Clone_Image]', 'F') AND parent_object_id = OBJECT_ID(N'[dbo].[Clone]', 'U'))
ALTER TABLE [dbo].[Clone] ADD CONSTRAINT [FK_Clone_Image] FOREIGN KEY ([ImageID]) REFERENCES [dbo].[Image] ([ImageID])

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_Clone_Host]', 'F') AND parent_object_id = OBJECT_ID(N'[dbo].[Clone]', 'U'))
ALTER TABLE [dbo].[Clone] ADD CONSTRAINT [FK_Clone_Host] FOREIGN KEY ([HostID]) REFERENCES [dbo].[Host] ([HostID])

IF @@ERROR <> 0 SET NOEXEC ON

COMMIT TRANSACTION

IF @@ERROR <> 0 SET NOEXEC ON

DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END

