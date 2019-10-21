CREATE FUNCTION [dbo].[DisplayPersons]
(
    @PersonNumber INTEGER
)
RETURNS VARCHAR(20)
AS
BEGIN
   DECLARE @PersonName AS VARCHAR(20);

   SELECT @PersonName = FirstName + ' ' + LastName
   FROM [dbo].Person
   WHERE PersonId = @PersonNumber;
   RETURN @PersonName;
END;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Person]
(
   [PersonId] [int] IDENTITY(1,1) NOT NULL,
   [FirstName] [varchar](50) NOT NULL,
   [LastName] [varchar](50) NOT NULL,
   [Address] [varchar](100) NOT NULL,
   [City] [varchar](50) NOT NULL,
   [Zipcode] [varchar](8) NOT NULL,
   [Country] [varchar](50) NOT NULL,
   [Email] [varchar](100) NOT NULL,
   CONSTRAINT [PK_Person] PRIMARY KEY CLUSTERED
(
	[PersonId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [NIX__Person_FirstNameLastName] ON [dbo].[Person]
(
	[FirstName] ASC,
	[LastName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[Person1]
AS
   SELECT PersonId, FirstName, LastName
   FROM dbo.Person
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
Description:
Create a new person

Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
10/08/2019	Sander Stad				Initial procedure
*/
CREATE PROCEDURE [dbo].[Person_Create]
   @PersonID INT OUTPUT,
   @FirstName VARCHAR(50) = NULL,
   @LastName VARCHAR(50) = NULL,
   @Address VARCHAR(100) = NULL,
   @City VARCHAR(50) = NULL,
   @Zipcode VARCHAR(8) = NULL,
   @Country VARCHAR(50) = NULL,
   @Email VARCHAR(100) = NULL
AS
BEGIN


   -- Set session options to make sure transactions are aborted correctly
   -- and the procedure doesn't return the count
   SET XACT_ABORT, NOCOUNT ON;

   -- Check the parameters
   IF (@FirstName IS NULL)
    BEGIN
      ;
      THROW 50000, 'Invalid parameter: @FirstName cannot be NULL!', 1;
      RETURN;
   END;

   -- Declare variables
   DECLARE @sqlcmd NVARCHAR(MAX);
   DECLARE @params NVARCHAR(MAX);



   -- Set the SQL command
   SET @sqlcmd
        = N'
			INSERT INTO dbo.Person(FirstName,LastName,Address,City,Zipcode,Country,Email)
			VALUES (@FirstName, @LastName, @Address, @City, @Zipcode, @Country, @Email);

			SELECT @PersonID = SCOPE_IDENTITY();
		';

   SET @params
        = N'
			@PersonID INT OUTPUT,
			@FirstName VARCHAR(50),
			@LastName VARCHAR(50),
			@Address VARCHAR(100),
			@City VARCHAR(50),
			@Zipcode VARCHAR(8),
			@Country VARCHAR(50),
			@Email VARCHAR(100)
		';

   EXECUTE sp_executesql @stmnt = @sqlcmd,
                          @params = @params,
                          @FirstName = @FirstName,
                          @LastName = @LastName,
                          @Address = @Address,
                          @City = @City,
                          @Zipcode = @Zipcode,
                          @Country = @Country,
                          @Email = @Email,
                          @PersonID = @PersonID OUTPUT;

END;

-- Cleanup
DROP PROCEDURE IF EXISTS [dbo].[Person_GetAll];
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Description:
Procedure to get all persons

Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
10/08/2019	Sander Stad				Initial procedure
*/
CREATE PROCEDURE [dbo].[Person_GetAll]
AS
BEGIN
   SET NOCOUNT ON;

   -- Execute the SQL command
   SELECT PersonId,
      FirstName,
      LastName,
      Address,
      City,
      Zipcode,
      Country,
      Email
   FROM [dbo].[Person];

END;
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties =
   Begin PaneConfigurations =
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane =
      Begin Origin =
         Top = 0
         Left = 0
      End
      Begin Tables =
         Begin Table = "Person"
            Begin Extent =
               Top = 6
               Left = 38
               Bottom = 136
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane =
   End
   Begin DataPane =
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane =
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Person1'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Person1'
GO
