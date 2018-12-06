<cfcomponent output="false">

	<cfset container = {}>
	<cfset container.maxLinks = "0" />
	<cfset container.excludeFilters = "" />

	<cfset container.qData = QueryNew('url,title,body,itemDate', 'varchar,varchar,varchar,date') />
	<cfset container.qLinks = QueryNew('url', 'varchar') />


	<cffunction name="indexPage" access="remote">
		<cfargument name="pageData" default="" />

		<cfset title = pageData.title>
		<cfset body = pageData.body>
		<cfset titleAr = ListToArray(title,' ')>


		<cfscript>
			writedump(titleAr,"console");
			for(str in titleAr){
				strVal = Trim(str);
				strVal = strVal.toLowerCase();
				cacheput(strVal, body);
			}
		</cfscript>

	</cffunction>

	<cffunction name="crawl" access="remote">
		<cfargument name="site" default="" />
		<cfargument name="extensions" default="" />
		<cfargument name="excludeFilters" default="" />
		<cfargument name="maxLinks" default="0" />

		<cfif IsValid('URL', ARGUMENTS.site) and GetStatus(ARGUMENTS.site)>
			<cfset container.maxLinks = Val(ARGUMENTS.maxLinks) />
			<cfset container.excludeFilters = ARGUMENTS.excludeFilters />
			<cfset container.extensions = ARGUMENTS.extensions />
			<cfset checkLinks(ARGUMENTS.site, ARGUMENTS.site, ARGUMENTS.extensions) />
		</cfif>
		
		<cfreturn container.qData />
	</cffunction>

	<cffunction name="getStatus">
		<cfargument name="link" required="true" />

		<cfset var result = 0 />
		<cfhttp method="head" url="#ARGUMENTS.link#" redirect="true" timeout="5"></cfhttp>
		<cfset result = Val(cfhttp.statusCode) /><cfreturn result />
		
	</cffunction>

	<cffunction name="shouldFollow">
		<cfargument name="link" required="true" />
		<cfargument name="domain" required="true" />
		
		<cfset var result = true />

		<cfquery name="qHasBeenChecked" dbtype="query">
			SELECT url
			FROM container.qLinks
			WHERE url = '#ARGUMENTS.link#'
		</cfquery>

		<cfif qHasBeenChecked.recordCount>
			<cfset result = false />
		<cfelseif ARGUMENTS.link contains 'javascript:'>
			<cfset result = false />
		<cfelseif Val(container.maxLinks) and container.qLinks.recordCount gte Val(container.maxLinks)>
			<cfset result = false />
		<cfelseif Left(link, Len(ARGUMENTS.domain)) neq ARGUMENTS.domain>
			<cfset result = false />
		</cfif>
		
		<cfreturn result />
	</cffunction>

	<cffunction name="shouldIndex">
		<cfargument name="link" required="true" />
		
		<cfset var result = true />

		<cfif ListLen(container.extensions) and not ListFindNoCase(container.extensions, ListLast(ListFirst(ARGUMENTS.link, '?'), '.'))>
			<cfset result = false />
		<cfelseif ListLen(container.excludeFilters)>
			<cfloop index="filter" list="#container.excludeFilters#" delimiters="|">
				<cfset literalFilter = Replace(filter, '*', '', 'ALL')>
				<cfif Left(filter, 1) eq '*' and Right(filter, 1) eq '*'>
					<cfif link contains literalFilter>
						<cfset result = false />
					</cfif>
				<cfelseif Right(filter, 1) eq '*'>
					<cfif Left(link, Len(literalFilter)) eq literalFilter>
						<cfset result = false />
					</cfif>
				<cfelseif Left(filter, 1) eq '*'>
					<cfif Right(link, Len(literalFilter)) eq literalFilter>
						<cfset result = false />
					</cfif>
				<cfelse>
					<cfif link eq filter>
						<cfset result = false />
					</cfif>
				</cfif>
			</cfloop>
		</cfif>
		
		<cfreturn result />
	</cffunction>

	<cffunction name="checkLinks">
		<cfargument name="page" required="true" />
		<cfargument name="domain" required="true" />

		<cfset var link = '' />

		<!--- Get the page --->
		<cfhttp method="get" url="#ARGUMENTS.page#" redirect="true" resolveurl="true" timeout="10"></cfhttp>

		<cfset QueryAddRow(container.qLinks) />
		<cfset QuerySetCell(container.qLinks, 'url', ARGUMENTS.page) />

		<cfif Val(CFHTTP.statusCode) eq 200>
			<cfif shouldIndex (ARGUMENTS.page)>

				<cfset QueryAddRow(container.qData) />
				<cfset QuerySetCell(container.qData, 'url', getRelativePath(ARGUMENTS.page)) />
				<cfset QuerySetCell(container.qData, 'title', getPageTitle(CFHTTP.fileContent)) />
				<cfset QuerySetCell(container.qData, 'body', getBrowsableContent(CFHTTP.fileContent)) />
				<cfset QuerySetCell(container.qData, 'itemDate', '') />
			</cfif>

			<cfset aLinks = ReMatchNoCase('((((https?:|ftp : ) \/\/)|(www\.|ftp\.))[-[:alnum:]\?$%,\.\/\|&##!@:=\+~_]+[A-Za-z0-9\/])', StripComments(cfhttp.fileContent)) />
			<cfloop index="link" array="#aLinks#">

				<cfset link = Replace(ListFirst(link, '##'), ':80', '', 'ONE') />

				<cfif shouldFollow(link, ARGUMENTS.domain)>
					<cfset linkStatus = GetStatus(link) />

					<cfif linkStatus eq 200>
						<!--- Link check its contents as well --->
						<cfset checkLinks(link, ARGUMENTS.domain)>
					</cfif>
				</cfif>
			</cfloop>
		</cfif>

		<cfreturn />
	</cffunction>

	<cffunction name="getBrowsableContent">
		<cfargument name="string" required="true" />

		<cfset ARGUMENTS.string = StripComments(ARGUMENTS.string) />
		<cfset ARGUMENTS.string = ReReplaceNoCase(ARGUMENTS.string, '<script.*?>.*?</script>', '', 'ALL') />
		<cfset ARGUMENTS.string = ReReplaceNoCase(ARGUMENTS.string, '<style.*?>.*?</style>', '', 'ALL') />
		<cfset ARGUMENTS.string = ReReplace(ARGUMENTS.string, '<[^>]*>', '', 'ALL') />

		<cfreturn ARGUMENTS.string />
	</cffunction>

	<cffunction name="stripComments">
		<cfargument name="string" required="true" />

		<cfset ARGUMENTS.string = ReReplace(ARGUMENTS.string, '<--[^(--&gt  ) ]*-->', '', 'ALL') />

		<cfreturn ARGUMENTS.string />
	</cffunction>

	<cffunction name="getPageTitle">
		<cfargument name="string" required="true" />

		<cfreturn ReReplace(ARGUMENTS.string, ".*<title>([^<>]*)</title>.*", "\1") />
	</cffunction>

	<cffunction name="getRelativePath">
		<cfargument name="path" required="true" />

		<cfset ARGUMENTS.path = ReplaceNoCase(ARGUMENTS.path, 'http://', '', 'ONE') />
		<cfset ARGUMENTS.path = ReplaceNoCase(ARGUMENTS.path, ListFirst(ARGUMENTS.path, '/'), '', 'ONE') />

		<cfreturn ARGUMENTS.path />
	</cffunction>
	
</cfcomponent>
