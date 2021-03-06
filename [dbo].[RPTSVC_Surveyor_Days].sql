USE [GrassHopper]
GO
/****** Object:  StoredProcedure [dbo].[RPTSVC_Surveyor_Days]    Script Date: 01/21/2015 12:08:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ------------------------------------------------------------------------------------------------------------------------------------------
-- Author:	Mike B.
-- Purpose:	Get data for the "Surveyor Days" report for Surveyor HR. Surveyor assignments based on filters
-- Created:	Sept 4, 2013(some code moved forward from rpt_surveyor_days and was enhanced)
-- ------------------------------------------------------------------------------------------------------------------------------------------
ALTER proc [dbo].[RPTSVC_Surveyor_Days]
(
	@Sector varchar(200),
	@primarySector int,
	@sectionCollection varchar(200),
	@profession varchar(200),
	@primaryProfession int,
	@language varchar(200),
	@primaryLanguage int,
	@status varchar(50),
	@sdate datetime,
	@edate datetime,
	@TeamLeader bit,
	@Facilitator bit
)
AS

-- -------------------------------------------------------------------------------------------------
-- Test block
-- -------------------------------------------------------------------------------------------------
--declare	
--	@Sector varchar(200),
--	@primarySector int,
--	@sectionCollection varchar(200),
--	@profession varchar(200),
--	@primaryProfession int,
--	@language varchar(200),
--	@primaryLanguage int,
--	@status varchar(50) ,
--	@sdate datetime,
--	@edate datetime,
--	@TeamLeader bit,
--	@Facilitator bit
		
--set @Sector = '59,71' -- Home Care, Long Term Care
--set @primarySector = 1
--set @sectionCollection = '1,2,3,4,5,6,7,8,9,10'
--set @profession = '1,2,3,4,5,6,7,8,9,10'
--set @primaryProfession = 0
--set @language = '6,8' -- Engish,French
--set @primaryLanguage = 0
--set @status = '4,13,15' -- Intern, Active, Fellow
--set	@sdate = '2013-09-01'
--set @edate = '2014-01-01'
--SET @TeamLeader = 0
--SET @Facilitator = 0
-- -------------------------------------------------------------------------------------------------
		
SELECT 
	s.Lastname + ', '+ s.firstname as [Name],
	CASE WHEN s.Facilitator = 1 then 'Yes' else 'No' end as [Facilitate],
	CASE WHEN s.TeamLeader = 1 then 'Yes' else 'No' end as [TeamLead],
	pt.title as PrimaryProfession,
	ls.Title as PrimaryHealthSector,
	convert(varchar(10),s.DateJoined,101) as DateJoined,
	tl.title as PrimaryLanguage,
	sstl.Title as SurveyorStatus,
	convert(varchar(10),data.planningstartdate,101) as PlanningStartDate, 
	convert(varchar(10),data.enddate,101) as SurveyEndDate,
	data.InstitutionName, 
	data.SurveyorRole,
	data.SurveyDayCount
FROM 
	tblsurveyors s
	LEFT JOIN lnkSurveyorProfession sp ON 
		sp.surveyorid = s.id  
		AND sp.isprimary=1
	LEFT JOIN dbo.tblprofessiontext pt ON 
		pt.professionid = sp.professionid 
		AND pt.culture = 'en-ca'
	LEFT JOIN dbo.lnkSectorSurveyor sse ON 
		sse.surveyorid = s.id  
		AND sse.isprimary = 1
		and sse.IsCurrentRecord = 1
		and sse.DateFrom <= GETDATE()
		and (sse.DateTo IS NULL OR sse.DateTo >= GETDATE())
	LEFT JOIN lkpSectors ls ON 
		ls.ID = sse.sectorID 
		AND ls.culture = 'en-ca'
	LEFT JOIN dbo.tblSurveyorLanguages sl ON 
		sl.surveyorid = s.id  and sl.isprimary=1
	LEFT JOIN dbo.tblLanguageText tl ON 
		sl.LanguageID = tl.LanguageID 
		AND tl.culture = 'en-ca'
	LEFT JOIN dbo.lnkSurveyorStatusSurveyor sss ON 
		sss.SurveyorID = s.id 
		AND getdate() between fromdate 
		AND isnull( todate, getdate() + 1 )
	LEFT JOIN dbo.tblSurveyorStatusText sstl ON 
		sstl.SurveyorStatusID = sss.SurveyorStatusID 
		AND sstl.culture = 'en-ca'
	LEFT JOIN
		(
			-- Surveyor Assignments --
			SELECT  
				las.SurveyorID as SurveyorID,
				tsss.planningstartdate as planningstartdate, 
				tsss.SurveyEndDate as enddate, 
				org.OrgName as InstitutionName, 
				srt.Textdetail as SurveyorRole,
				las.SurveyDays as SurveyDayCount 
			FROM 
				lnkAssignSurveyors las
 				INNER JOIN tblsurveyinfo tsi ON 
					las.surveyid = tsi.id
				INNER JOIN tblsurveyschedule tsss ON 
					tsss.surveyid = tsi.id 
				INNER JOIN tblOrganizations org ON 
					org.ID = tsi.OrgID
				INNER JOIN tblSurveyorRoleText srt ON
					srt.SurveyorRoleID = las.RoleID
					and srt.Culture = 'en-CA'
			WHERE
				tsss.surveystartdate >= @sdate 
				AND tsss.surveystartdate <= @edate
				and las.AssignmentStatusID=3
				and org.istestorg <> 1
		) data ON 
				data.SurveyorID = s.ID
WHERE
	-- Filter out surveyors based on all selected health sectors. 
	s.id in (
				SELECT ss.id 
				FROM tblsurveyors ss		
				WHERE 
				(
					SELECT count(*) 
					FROM dbo.lnkSectorSurveyor 
					WHERE 
						lnkSectorSurveyor.surveyorid = ss.id 
						and SectorID in (SELECT item FROM dbo.split(@sector,','))
						and ((@primarySector = 1 and IsPrimary = 1) OR (@primarySector = 2))
						and IsCurrentRecord = 1
						and DateFrom <= GETDATE()
						and (DateTo IS NULL OR DateTo >= GETDATE())
				) > 0 
			 )	

	-- Filter out surveyors based on all selected professions.
	and	s.id in	(	
					
					select ss.id 
					from tblsurveyors ss
					where (		
							select count(*) 
							from lnkSurveyorProfession
							where	lnkSurveyorProfession.surveyorid = ss.id 
									and professionid in (select item from dbo.split(@profession, ',' ))
									and ((@primaryProfession = 1 and IsPrimary = 1) OR (@primaryProfession = 2))
							) > 0
			 )
			 
	-- Filter out surveyors based on all selected languages.
	and s.id in (
					select ss.id 
					from tblsurveyors ss
					where (
							select count(*) 
							from tblSurveyorLanguages sl
							where sl.surveyorid = ss.id 
									and sl.languageid in (select item from dbo.split(@language,','))
									and sl.Oral = 1
									and sl.Reading = 1
									and sl.Written = 1
									and ((@primaryLanguage = 1 and sl.IsPrimary = 1) OR (@primaryLanguage = 2))
							) > 0 
					
				 )
				 
	-- Filter out surveyors based on all selected statuses.			 
	and sss.SurveyorStatusID in (select (item) from dbo.split(@status,','))

	-- Filter out surveyors based on standards(section collection) selected for the surveyor.
	and s.ID in(select SurveyorID from lnkSectionCollection_Surveyor lscs 
				where lscs.SectionCollectionID in(select item from dbo.split(@sectionCollection,','))
						and lscs.IsCurrentRecord = 1
						and lscs.DateFrom < GETDATE()
						and (lscs.DateTo is null OR lscs.DateTo > GETDATE()) 
				)
	-- Filter to Team Leaders if set to True(1)
	AND (s.TeamLeader = @TeamLeader OR @TeamLeader = 0)
	
	-- Filter to Facilitators if set to True(1)
	AND (s.Facilitator = @Facilitator OR @Facilitator = 0)
ORDER BY
	s.Lastname + ', '+ s.firstname



---- --------------------------------------------------------------------------------------------------------------------
---- These are all the selects that source the drop down lists for the parameters in the "Surveyor Days" Report.
---- Do not delete this code	
---- --------------------------------------------------------------------------------------------------------------------

---- Sector --
--select ID,title as Sector
--from GrassHopper..lkpSectors
--where Culture = 'en-ca' 
--order by SortOrder

---- Standard --
--select sc.ID as ID, sct.TextDetail as SectionCollection 
--from NapStandards..tblSectionCollections sc
--	inner join NapStandards..tblSectionCollectionText sct on sc.id = sct.sectionCollectionID
--where
--	ValidFrom < GETDATE() and (validTo is null or validTo > GETDATE())
--	and sct.Culture = 'en-ca'
--order by 
--	sct.TextDetail
	
---- Profession --
--select ProfessionID as ID, Title as Profession
--from GrassHopper..tblProfessionText
--where Culture = 'en-ca'
--order by title

---- SurveyorStatus --
--select SurveyorStatusID as ID, Title as SurveyorStatus 
--from GrassHopper..tblSurveyorStatusText sst
--where Culture = 'en-ca'
--order by sst.Title

---- Language --
--select LanguageID as ID,title as LanguageText
--from GrassHopper..tblLanguageText 
--where Culture = 'en-ca' 
--order by title

---- --------------------------------------------------------------------------------------------------------------------
---- These are all the selects that source the drop down lists for the parameters in the "Surveyor Days" Report.
---- Do not delete this code	
---- --------------------------------------------------------------------------------------------------------------------

