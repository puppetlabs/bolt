<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                exclude-result-prefixes="xs dita-ot">
  
  <xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-textonly.xsl"/>
  
  <xsl:output method="xml" encoding="utf-8" indent="no" />
  
  <!-- =========== DEFAULT VALUES FOR EXTERNALLY MODIFIABLE PARAMETERS =========== -->
  <!-- output type -->
  <xsl:param name="FINALOUTPUTTYPE" select="''"/>
  <xsl:param name="INPUTMAP" select="''"/>
  <xsl:param name="WORKDIR">
    <xsl:apply-templates select="/processing-instruction('workdir-uri')[1]" mode="get-work-dir"/>
  </xsl:param>
  <xsl:param name="include.rellinks" select="'#default parent child sibling friend next previous cousin ancestor descendant sample external other'"/>
  <xsl:variable name="include.roles" select="tokenize($include.rellinks, '\s+')" as="xs:string*"/>
  <xsl:variable name="file-prefix" select="$WORKDIR" as="xs:string"/>
  <xsl:variable name="PATHTOMAP" as="xs:string?">
    <xsl:value-of>
     <xsl:call-template name="GetPathToMap">
       <xsl:with-param name="inputMap" select="$INPUTMAP"/>
     </xsl:call-template>
    </xsl:value-of>
  </xsl:variable>
  <xsl:variable name="DIRS-IN-MAP-PATH" as="xs:integer">
    <xsl:call-template name="countDirectoriesInPath">
      <xsl:with-param name="path" select="$PATHTOMAP"/>
    </xsl:call-template>
  </xsl:variable>  

  <!-- Define the error message prefix identifier -->
  <xsl:variable name="msgprefix" select="'DOTX'"/>
    
  <xsl:template match="/">
    <xsl:variable name="map" as="document-node()">
      <xsl:document>
        <xsl:apply-templates select="node()" mode="strip"/>
      </xsl:document>
    </xsl:variable>
    <xsl:apply-templates select="$map/node()"/>
  </xsl:template>
  
  <xsl:template match="node() | @*" mode="strip">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*" mode="strip"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' ditaot-d/submap ')]" mode="strip">
    <xsl:apply-templates select="node()" mode="strip"/>
  </xsl:template>

  <!-- Start by creating the collection element for the map being processed. -->
  <xsl:template match="/*[contains(@class, ' map/map ')]">    
    <mapcollection>
      <xsl:apply-templates/>
    </mapcollection>
  </xsl:template>
    
  <!-- Get the relative path that leads to a file. Used to find path from a maplist to a map. -->
  <xsl:template name="getRelativePath">
    <xsl:param name="filename" as="xs:string"/>
    <xsl:param name="currentPath" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="contains($filename,'/')">
        <xsl:call-template name="getRelativePath">
          <xsl:with-param name="filename" select="substring-after($filename,'/')"/>
          <xsl:with-param name="currentPath" select="concat($currentPath, substring-before($filename,'/'), '/')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$currentPath"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Match a topicref. Create all of the hierarchy links associated with the topicref. -->
  <xsl:template match="*[@href and not(@href = '')]
                        [not(@linking = ('none', 'targetonly') or @scope = ('external', 'peer'))]
                        [not(@format) or @format = 'dita']">
    <!-- Href that points from this map to the topic this href references. -->
    <xsl:param name="pathFromMaplist" as="xs:string?" tunnel="yes"/>
    <xsl:variable name="use-href">
      <xsl:choose>
        <xsl:when test="@copy-to and (not(@format) or @format = 'dita') and not(contains(@chunk, 'to-content'))">
          <xsl:value-of select="dita-ot:normalize-uri(@copy-to)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="dita-ot:normalize-uri(@href)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="hrefFromOriginalMap" select="dita-ot:normalize-uri(concat($pathFromMaplist, $use-href))"
      as="xs:string"/>
    
    <!-- Path from the topic back to the map's directory (with map): for ref/abc.dita, will be "../" -->
    <xsl:variable name="pathBackToMapDirectory" as="xs:string">
      <xsl:call-template name="pathBackToMapDirectory">
        <xsl:with-param name="path">
          <xsl:choose>
            <xsl:when test="contains($use-href,'#')">
              <xsl:value-of select="substring-before($use-href,'#')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$use-href"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:with-param>
        <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- If going to print, and @print=no, do not create links for this topicref -->
    <xsl:if test="not(($FINALOUTPUTTYPE = 'PDF' or $FINALOUTPUTTYPE = 'IDD') and @print = 'no')">
      <xsl:variable name="newlinks">
        <maplinks href="{$hrefFromOriginalMap}">
          <xsl:apply-templates select="." mode="generate-all-links">
            <xsl:with-param name="pathBackToMapDirectory" select="$pathBackToMapDirectory" tunnel="yes"/>
          </xsl:apply-templates>
        </maplinks>
      </xsl:variable>
      <xsl:apply-templates select="$newlinks" mode="add-links-to-temp-file"/>
    </xsl:if>
    <xsl:apply-templates>
      <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- "add-links-to-temp-file" mode added with SF Bug 2573681  -->
  <!-- If <maplinks> has any links in the linklist or linkpool, -->
  <!-- then add it to the temp file.                            -->
  <xsl:template match="maplinks" mode="add-links-to-temp-file">
    <xsl:if test="*/*">
      <xsl:copy>
        <xsl:copy-of select="@*"/>
        <xsl:apply-templates mode="add-links-to-temp-file"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
  <!-- Match the linklist or linkpool. If it has any children, add it to the temp file. -->
  <!-- If the linklist or linkpool are empty, they will not be added. -->
  <xsl:template match="*" mode="add-links-to-temp-file">
    <xsl:if test="*">
      <xsl:copy-of select="."/>
    </xsl:if>
  </xsl:template>
  
  <!-- Generate both unordered <linkpool> and ordered <linklist> links. -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]" mode="generate-all-links">
    <xsl:apply-templates select="." mode="generate-ordered-links"/>
    <xsl:apply-templates select="." mode="generate-unordered-links"/>
  </xsl:template>

  <!-- Generated ordered links to friends (with linklist) -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]" mode="generate-ordered-links">
    <xsl:apply-templates select="." mode="link-to-friends">
      <xsl:with-param name="linklist" select="true()" as="xs:boolean"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Generate unordered links (with linkpool) -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]" mode="generate-unordered-links">
    <linkpool class="- topic/linkpool ">
      <xsl:copy-of select="@xtrf | @xtrc"/>
      <xsl:if test="/*[@id]">
        <xsl:attribute name="mapkeyref" select="/*/@id"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="link-from"/>
    </linkpool>
  </xsl:template>

  <!-- To do: When XSLT 2.0 is a minimum requirement, do this again with hearty use of xsl:next-match. -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]" mode="link-from">
    <xsl:if test="$include.roles = 'parent'">
      <xsl:apply-templates select="." mode="link-to-parent"/>
    </xsl:if>
    <xsl:apply-templates select="." mode="link-to-prereqs"/>
    <xsl:if test="$include.roles = 'sibling'">
      <xsl:apply-templates select="." mode="link-to-siblings"/>
    </xsl:if>
    <xsl:if test="$include.roles = ('next', 'previous')">
      <xsl:apply-templates select="." mode="link-to-next-prev"/>
    </xsl:if>
    <xsl:if test="$include.roles = 'child'">
      <xsl:apply-templates select="." mode="link-to-children"/>
    </xsl:if>
    <xsl:if test="$include.roles = 'friend'">
      <xsl:apply-templates select="." mode="link-to-friends">
        <xsl:with-param name="linklist" select="false()" as="xs:boolean"/>
      </xsl:apply-templates>
    </xsl:if>
    <xsl:if test="$include.roles = 'other'">
      <xsl:apply-templates select="." mode="link-to-other"/>
    </xsl:if>
  </xsl:template>

  <!--parent-->
  <xsl:template match="*" mode="link-to-parent"/>
  <xsl:template match="*[contains(@class, ' map/topicref ')][not(ancestor::*[contains(concat(' ', @chunk, ' '), ' to-content ')])]"
                mode="link-to-parent" name="link-to-parent">
    <xsl:apply-templates select="ancestor::*[contains(@class, ' map/topicref ')]
                                            [@href and not(@href = '')]
                                            [not(@linking = ('none', 'sourceonly'))]
                                            [not(@processing-role = 'resource-only')][1]"
                          mode="link">
      <xsl:with-param name="role">parent</xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <!--prereqs - preceding with importance=required and in a sequence, but leaving the immediately previous one alone to avoid duplication with prev/next generation-->
  <xsl:template match="*" mode="link-to-prereqs"/>
  <xsl:template match="*[@collection-type = 'sequence']/*[contains(@class, ' map/topicref ')]
                                                         [not(ancestor::*[contains(concat(' ', @chunk, ' '), ' to-content ')])]"
                mode="link-to-prereqs" name="link-to-prereqs">
    <xsl:apply-templates select="preceding-sibling::*[contains(@class, ' map/topicref ')]
                                                     [@href and not(@href = '')]
                                                     [not(@linking = ('none', 'sourceonly'))]
                                                     [not(@processing-role = 'resource-only')]
                                                     [position() > 1]
                                                     [@importance = 'required']" mode="link"/>      
  </xsl:template>
  
  <!--family-->
  <xsl:template match="*" mode="link-to-siblings"/>
  <xsl:template match="*[@collection-type = 'family']/*[contains(@class, ' map/topicref ')]
                                                       [not(ancestor::*[contains(concat(' ', @chunk, ' '), ' to-content ')])]"
                mode="link-to-siblings" name="link-to-siblings">
    <xsl:apply-templates select="preceding-sibling::*[contains(@class, ' map/topicref ')]
                                                     [@href and not(@href = '')]
                                                     [not(@linking = ('none', 'sourceonly'))]
                                                     [not(@processing-role = 'resource-only')]"
                         mode="link">
      <xsl:with-param name="role">sibling</xsl:with-param>
    </xsl:apply-templates>
    <xsl:apply-templates select="following-sibling::*[contains(@class, ' map/topicref ')]
                                                     [@href and not(@href = '')]
                                                     [not(@linking = ('none', 'sourceonly'))]
                                                     [not(@processing-role = 'resource-only')]"
                         mode="link">
      <xsl:with-param name="role">sibling</xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <!--next/prev-->
  <xsl:template match="*" mode="link-to-next-prev"/>
  <xsl:template match="*[@collection-type = 'sequence']/*[contains(@class, ' map/topicref ')]
                                                         [not(ancestor::*[contains(concat(' ', @chunk, ' '), ' to-content ')])]"
                mode="link-to-next-prev" name="link-to-next-prev">
    <xsl:if test="$include.roles = 'previous'">
      <xsl:apply-templates select="preceding-sibling::*[contains(@class, ' map/topicref ')]
                                                       [@href and not(@href = '')]
                                                       [not(@linking = ('none', 'sourceonly'))]
                                                       [not(@processing-role = 'resource-only')][1]"
                           mode="link">
        <xsl:with-param name="role">previous</xsl:with-param>
      </xsl:apply-templates>
    </xsl:if>
    <xsl:if test="$include.roles = 'next'">
      <xsl:apply-templates select="following-sibling::*[contains(@class, ' map/topicref ')]
                                                       [@href and not(@href = '')]
                                                       [not(@linking = ('none', 'sourceonly'))]
                                                       [not(@processing-role = 'resource-only')][1]"
                           mode="link">
        <xsl:with-param name="role">next</xsl:with-param>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
  
  <!--children-->
  <xsl:template match="*" mode="link-to-children"/>
  <xsl:template match="*[contains(@class, ' map/topicref ')]
                        [not(ancestor-or-self::*[contains(concat(' ', @chunk, ' '), ' to-content ')])]"
                mode="link-to-children" name="link-to-children">
    <!--???TO DO: should be linking to appropriate descendants, not just children - ie grandchildren of eg topicgroup (non-href/non-title topicrefs) children-->
    <xsl:if test="not(@processing-role = 'resource-only') and
                  descendant::*[contains(@class, ' map/topicref ')]
                               [@href and not(@href = '')]
                               [not(@linking = ('none', 'sourceonly'))]
                               [not(@processing-role = 'resource-only')]">
      <linkpool class="- topic/linkpool ">
        <xsl:copy-of select="@xtrf | @xtrc | @collection-type"/>
        <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="recusive"/>
      </linkpool>
    </xsl:if>
  </xsl:template>
  
  <!-- XXX: maprefs are resolved at this point, should never match -->
  <xsl:template match="*[contains(@class, ' mapgroup-d/mapref ')][local-name() = 'topicref']" mode="recusive">
    <xsl:apply-templates select="self::*[@href and not(@href = '')]
                                        [not(@linking = ('none', 'sourceonly'))]
                                        [not(@processing-role = 'resource-only')]"
                         mode="link">
      <xsl:with-param name="role">child</xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <!-- XXX: maprefs are resolved at this point, should never match -->
  <xsl:template match="*[contains(@class, ' mapgroup-d/mapref ')]" mode="recusive">
    <xsl:apply-templates select="self::*[contains(@class, ' mapgroup-d/mapref ')]/descendant::*[@href and not(@href = '')]
                                                                                               [not(@linking = ('none', 'sourceonly'))]
                                                                                               [not(@processing-role = 'resource-only')]"
                         mode="link">
      <xsl:with-param name="role">child</xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' mapgroup-d/topicgroup ')]" mode="recusive">
    <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="recusive"/>
  </xsl:template>
  <xsl:template match="*" mode="recusive" priority="-10">
    <xsl:apply-templates select="self::*[@href and not(@href = '')]
                                        [not(@linking = ('none', 'sourceonly'))]
                                        [not(@processing-role = 'resource-only')]"
                         mode="link">
      <xsl:with-param name="role">child</xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <!--friends-->
  <xsl:template match="*" mode="link-to-friends"/>
  <xsl:template match="*[contains(@class, ' map/relcell ')]//*[contains(@class, ' map/topicref ')]"
                mode="link-to-friends" name="link-to-friends">
    <xsl:param name="linklist" select="false()" as="xs:boolean"/>
    
    <xsl:variable name="position" as="xs:integer">
      <xsl:apply-templates mode="get-position" select="ancestor::*[contains(@class, ' map/relcell ')]"/>
    </xsl:variable>
    <xsl:variable name="group-title">
      <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position()=$position]" mode="grab-group-title"/>
    </xsl:variable>
    
    <xsl:for-each select="ancestor::*[contains(@class, ' map/relrow ')]/*[contains(@class, ' map/relcell ')][position()!=$position]">
      <xsl:if test="descendant::*[contains(@class, ' map/topicref ')][dita-ot:hasHrefOrLinktext(.)]">
        <xsl:variable name="cellposition" as="xs:integer">
          <xsl:apply-templates mode="get-position" select="."/>
        </xsl:variable>
        <xsl:variable name="cellgroup-title" as="xs:string?">
          <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position()=$cellposition]" mode="grab-group-title"/>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="$linklist and exists($cellgroup-title)">
            <xsl:apply-templates mode="generate-ordered-links-2" select=".">
              <xsl:with-param name="position" as="xs:integer" select="$cellposition"/>
              <xsl:with-param name="group-title" as="xs:string?" select="$cellgroup-title"/>
            </xsl:apply-templates>
          </xsl:when>
          <xsl:when test="not($linklist) and empty($cellgroup-title)">
            <xsl:apply-templates mode="link" select="descendant::*[contains(@class, ' map/topicref ')][dita-ot:hasHrefOrLinktext(.)]">
              <xsl:with-param name="role">friend</xsl:with-param>
            </xsl:apply-templates>            
          </xsl:when>
        </xsl:choose>
      </xsl:if>
    </xsl:for-each>

    <xsl:if test="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position()=$position]/*[contains(@class, ' map/topicref ')][dita-ot:hasHrefOrLinktext(.)]">
      <xsl:choose>
        <xsl:when test="$linklist and exists($group-title)">
          <xsl:apply-templates mode="generate-ordered-links-2" select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position()=$position]">
            <xsl:with-param name="role">friend</xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="not($linklist) and empty($group-title)">
          <xsl:apply-templates mode="link" select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position()=$position]/*[contains(@class, ' map/topicref ')][dita-ot:hasHrefOrLinktext(.)]">
            <xsl:with-param name="role">friend</xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
      </xsl:choose>
    </xsl:if>

  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/relcolspec ')]/*[contains(@class, ' map/topicref ')]"
                mode="link-to-friends" name="link-to-subfriends">
    <xsl:param name="linklist" select="false()" as="xs:boolean"/>
    <xsl:variable name="position" as="xs:integer">
      <xsl:apply-templates mode="get-position" select="ancestor::*[contains(@class, ' map/relcolspec ')]"/>
    </xsl:variable>
    <xsl:variable name="group-title">
      <xsl:apply-templates mode="grab-group-title" select="."/>
    </xsl:variable>
    <xsl:if test="$linklist and exists($group-title) and not($group-title = '')">
      <linklist class="- topic/linklist ">
        <xsl:copy-of select="@xtrf | @xtrc"/>
        <xsl:if test="/*[@id]">
          <xsl:attribute name="mapkeyref" select="/*/@id"/>
        </xsl:if>
        <title class="- topic/title ">
          <xsl:value-of select="$group-title"/>
        </title>
        <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relrow ')]/*[contains(@class, ' map/relcell ')][position() = $position]//*[contains(@class, ' map/topicref ')][dita-ot:hasHrefOrLinktext(.)]" mode="link">
          <xsl:with-param name="role">friend</xsl:with-param>
        </xsl:apply-templates>
      </linklist>
    </xsl:if>
    <xsl:if test="not($linklist) and (empty($group-title) or $group-title = '')">
      <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relrow ')]/*[contains(@class, ' map/relcell ')][position() = $position]//*[contains(@class, ' map/topicref ')][dita-ot:hasHrefOrLinktext(.)]" mode="link">
        <xsl:with-param name="role">friend</xsl:with-param>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
  
  <!-- Get the position of current element -->
  <xsl:template match="*[contains(@class, ' map/relheader ') or contains(@class, ' map/relrow ')]/*" mode="get-position" as="xs:integer">
    <xsl:sequence select="count(preceding-sibling::*) + 1"/>
  </xsl:template>
  
  <!-- Grab the group title from the matching header of reltable. -->
  <xsl:template match="*[contains(@class, ' map/relcolspec ')]" mode="grab-group-title"> 
    <xsl:choose>
      <xsl:when test="*[contains(@class, ' topic/title ')][not(title = '')]">
        <xsl:value-of select="*[contains(@class, ' topic/title ')]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates mode="grab-group-title" select="*[contains(@class, ' map/topicref ')][1]"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>  
  
  <xsl:template match="*[contains(@class, ' map/topicref ')]" mode="grab-group-title" as="xs:string?">
    <xsl:variable name="file-origin" as="xs:string?">
      <xsl:if test="not(empty(@href)) and (empty(@format) or @format='dita') and (empty(@scope) or @scope='local')">
        <xsl:call-template name="get-file-uri">
          <xsl:with-param name="href" select="@href"/>
          <xsl:with-param name="file-prefix" select="$file-prefix"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="file" as="xs:string?">
      <xsl:if test="exists($file-origin)">
        <xsl:call-template name="replace-blank">
          <xsl:with-param name="file-origin">
            <xsl:value-of select="$file-origin"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:if>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="parent::*[contains(@class, ' map/relcolspec ')]/*[contains(@class, ' topic/title ')]">
        <xsl:apply-templates select="parent::*[contains(@class, ' map/relcolspec ')]/*[contains(@class, ' topic/title ')]" mode="text-only"/>
      </xsl:when>
      <xsl:when test="descendant::*[contains(@class,' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:apply-templates select="descendant::*[contains(@class,' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]" mode="text-only"/>
      </xsl:when>
      <xsl:when test="@navtitle and not(@navtitle = '')">
        <xsl:value-of select="@navtitle"/>
      </xsl:when>
      <xsl:when test="exists($file) and document($file,/)//*[contains(@class, ' topic/title ')]">
        <xsl:apply-templates select="document($file,/)//*[contains(@class, ' topic/title ')][1]" mode="text-only"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <!-- Override this moded template to add your own kinds of links. -->
  <xsl:template match="*" mode="link-to-other"/>
  
  <xsl:template mode="generate-ordered-links-2" match="*[contains(@class, ' map/relcell ')]">
    <xsl:param name="position" as="xs:integer">
      <xsl:apply-templates mode="get-position" select="."/>
    </xsl:param>
    <xsl:param name="group-title" as="xs:string?">
      <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position() = $position]" mode="grab-group-title"/>
    </xsl:param>
    <linklist class="- topic/linklist ">
      <xsl:copy-of select="@xtrf | @xtrc"/>
      <xsl:if test="/*[@id]">
        <xsl:attribute name="mapkeyref" select="/*/@id"/>
      </xsl:if>
      <xsl:if test="exists($group-title) and not($group-title = '')">
        <title class="- topic/title ">
          <xsl:value-of select="$group-title"/>
        </title>
        <xsl:apply-templates select="descendant::*[contains(@class, ' map/topicref ')]
                                                  [dita-ot:hasHrefOrLinktext(.)]"
                             mode="link">
          <xsl:with-param name="role">friend</xsl:with-param>
        </xsl:apply-templates> 
      </xsl:if>
    </linklist>
  </xsl:template>
  
  <xsl:template mode="generate-ordered-links-2" match="*[contains(@class, ' map/relcolspec ')]">
    <xsl:variable name="position" as="xs:integer">
      <xsl:apply-templates mode="get-position" select="."/>
    </xsl:variable>
    <xsl:variable name="group-title">
      <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position() = $position]" mode="grab-group-title"/>
    </xsl:variable>
    <linklist class="- topic/linklist ">
      <xsl:copy-of select="@xtrf | @xtrc"/>
      <xsl:if test="/*[@id]">
        <xsl:attribute name="mapkeyref" select="/*/@id"/>
      </xsl:if>
      <xsl:if test="exists($group-title) and not($group-title = '')">
        <title class="- topic/title ">
          <xsl:value-of select="$group-title"/>
        </title>
        <xsl:apply-templates mode="link" 
          select="descendant::*[contains(@class, ' map/topicref ')][@href and not(@href = '')][not(@linking = ('none', 'sourceonly'))]">
          <xsl:with-param name="role">friend</xsl:with-param>
        </xsl:apply-templates> 
      </xsl:if>
    </linklist>
  </xsl:template>
  
  <xsl:template mode="link" 
    match="*[dita-ot:hasHrefOrLinktext(.)][not(@processing-role = 'resource-only')]">
    <xsl:param name="role" as="xs:string?" select="()"/>
    <xsl:param name="otherrole" as="xs:string?" select="()"/>
    <xsl:param name="pathBackToMapDirectory" as="xs:string" tunnel="yes"/>
    <!-- child found tag -->
    <xsl:param name="found" select="true()" as="xs:boolean"/>
    <!-- If going to print, and @print=no, do not create links for this topicref -->
    <xsl:if test="not(($FINALOUTPUTTYPE = 'PDF' or $FINALOUTPUTTYPE = 'IDD') and @print = 'no') and 
                  not(@processing-role = 'resource-only') and $found">
      <link class="- topic/link ">
        <xsl:if test="@class">
          <xsl:attribute name="mapclass" select="@class"/>
        </xsl:if>
        <xsl:copy-of select="ancestor-or-self::*[@type][1]/@type |
                             ancestor-or-self::*[@platform][1]/@platform |
                             ancestor-or-self::*[@product][1]/@product |
                             ancestor-or-self::*[@audience][1]/@audience |
                             ancestor-or-self::*[@otherprops][1]/@otherprops |
                             ancestor-or-self::*[@rev][1]/@rev"/>
        <xsl:copy-of select="@importance | @xtrf | @xtrc"/>
        <xsl:if test="@href and not(@href = '')">
          <xsl:choose>
            <xsl:when test="ancestor-or-self::*[@scope]">
              <xsl:copy-of select="ancestor-or-self::*[@scope][1]/@scope"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="scope">local</xsl:attribute>
            </xsl:otherwise>
            </xsl:choose>
        <xsl:choose>
            <xsl:when test="ancestor-or-self::*[@format]">
              <xsl:copy-of select="ancestor-or-self::*[@format][1]/@format"/>    
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="format">dita</xsl:attribute>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:attribute name="href">
            <xsl:choose>
              <xsl:when test="starts-with(@href,'http://') or starts-with(@href,'/') or
                              starts-with(@href,'https://') or starts-with(@href,'ftp:/') or @scope = 'external'">
                <xsl:value-of select="@href"/>
              </xsl:when>
              <!-- If the target has a copy-to value, link to that -->
              <xsl:when test="@copy-to and not(contains(@chunk, 'to-content'))">
                <xsl:value-of select="dita-ot:normalize-uri(concat($pathBackToMapDirectory, @copy-to))"/>
              </xsl:when>
              <!--ref between two local paths - adjust normally-->
              <xsl:otherwise>
                <xsl:value-of select="dita-ot:normalize-uri(concat($pathBackToMapDirectory, @href))"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </xsl:if>
        <xsl:if test="exists($role)">
          <xsl:attribute name="role" select="$role"/>
        </xsl:if>
        <xsl:if test="exists($otherrole)">
          <xsl:attribute name="otherrole" select="$otherrole"/>
        </xsl:if>
        <!--figure out the linktext and desc-->
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="add-props-to-link"/>
        <xsl:if test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]">
          <!--Do not output linktext when The final output type is PDF or IDD
            The target of the HREF is a local DITA file
            The user has not specified locktitle to override the title -->
          <xsl:if test="not(($FINALOUTPUTTYPE = 'PDF' or $FINALOUTPUTTYPE = 'IDD') and (not(@scope) or @scope = 'local') and (not(@format) or @format = 'dita') and (not(@locktitle) or @locktitle = 'no'))">
            <linktext class="- topic/linktext ">
              <xsl:copy-of select="*[contains(@class, ' map/topicmeta ')]/processing-instruction()[name()='ditaot'][.='usertext' or .='gentext']"/>
              <xsl:copy-of select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]/node()"/>
            </linktext>
          </xsl:if>
        </xsl:if>
        <xsl:if test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/shortdesc ')]">
          <!-- add desc node and text -->
          <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/shortdesc ')]"/>
        </xsl:if>
        <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="add-props-to-link"/>
      </link>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="@*|node()" mode="add-props-to-link">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="add-props-to-link"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@imageref" mode="add-props-to-link">
    <xsl:param name="pathBackToMapDirectory" as="xs:string" tunnel="yes"/>
    <xsl:attribute name="imageref" select="concat($pathBackToMapDirectory,.)"/>    
  </xsl:template>
  
  <!-- create a template to get child nodes and text -->
  <xsl:template match="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/shortdesc ')]" name="node">
    <xsl:copy-of select="../processing-instruction()[name() = 'ditaot'][. = 'usershortdesc' or . = 'genshortdesc']"/>
    <desc class="- topic/desc ">
      <!-- get child node and text -->
      <xsl:copy-of select="node()"/>
    </desc>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/topicmeta ')]">
    <!--ignore topicmeta content when walking topicref/reltable tree - otherwise linktext content gets literally output-->
  </xsl:template>
  <xsl:template match="*[contains(@class, ' map/topicmeta ')]" mode="link">
    <!--ignore topicmeta content when walking topicref/reltable tree - otherwise linktext content gets literally output-->
  </xsl:template>
  
  <!-- Get the path to map by removing the last filename from the inputMap.
       e.g. inputMap is 'aaa/bbb/ccc.ditamap' , output will be 'aaa/bbb' -->
  <xsl:template name="GetPathToMap">
    <xsl:param name="inputMap" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="contains($inputMap,'/')">
        <xsl:value-of select="substring-before($inputMap,'/')"/>
        <xsl:text>/</xsl:text>
        <xsl:call-template name="GetPathToMap">
          <xsl:with-param name="inputMap" select="substring-after($inputMap, '/')"/>
        </xsl:call-template>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <!-- Get the number of directories in the given path -->
  <xsl:template name="countDirectoriesInPath" as="xs:integer">
    <xsl:param name="path" as="xs:string"/>
    <xsl:param name="currentCount" as="xs:integer" select="0"/>
    <xsl:choose>
      <xsl:when test="contains($path, '/')">
        <xsl:call-template name="countDirectoriesInPath">
          <xsl:with-param name="path" select="substring-after($path, '/')"/>
          <xsl:with-param name="currentCount" select="$currentCount + 1"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$currentCount"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
    
  <!-- Compute the path back to the input ditamap directory 
       base on the given path. -->
  <xsl:template name="pathBackToMapDirectory" as="xs:string">
    <xsl:param name="path" as="xs:string"/>
    <!-- Portion of the href that still needs to be evaluated -->
    <xsl:param name="back" as="xs:string?"/>
    <!-- Relpath builds up as we go; add ../ here each time a directory is removed -->
    <xsl:param name="pathFromMaplist" as="xs:string?" select="''"/>
    <xsl:choose>
      <!-- If the path starts with ../ do not add to $back -->
      <xsl:when test="starts-with($path,'../')">
        <xsl:choose>
          <!-- For links such as plugin-one/../plugin-two/ref/a.dita, we have already
             gone up one by the time we get here. We can skip the ../ jump, and remove
             one of the pathBackToMapDirectory values we've already added. -->
          <xsl:when test="string-length($back) > 0 and starts-with($path,'../')">
            <xsl:call-template name="pathBackToMapDirectory">
              <xsl:with-param name="path" select="substring-after($path,'../')"/>
              <xsl:with-param name="back" select="substring-after($back,'../')"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="getPathBackToBase">
              <xsl:with-param name="path" select="$path"/>
              <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- It contains a directory, with only one type of slash; remove the first dir, add ../ to $back -->
      <xsl:when test="contains($path,'/')">
        <xsl:call-template name="pathBackToMapDirectory">
          <xsl:with-param name="path" select="substring-after($path,'/')"/>
          <xsl:with-param name="back" select="normalize-space(concat($back,'../'))"/>
        </xsl:call-template>
      </xsl:when>
      <!-- When there are no more directories in $path, return the current value of $back -->
      <xsl:otherwise>
        <xsl:value-of select="$back"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- If an href in this map starts with ../ then find the path back to the map -->
  <xsl:template name="getPathBackToBase" as="xs:string">
    <xsl:param name="path" as="xs:string"/>
    <xsl:param name="pathFromMaplist" as="xs:string?"/>
    <!-- The href value -->
    <xsl:variable name="directoriesBack" as="xs:integer">
      <!-- Number of directories above the map that $path travels -->
      <xsl:call-template name="countRelpaths">
        <xsl:with-param name="path" select="$path"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="moveToBase">
      <!-- Path from the closest common ancestor, back to the base -->
      <xsl:call-template name="MoveBackToBase">
        <xsl:with-param name="saveDirs" as="xs:integer">
          <xsl:value-of select="$directoriesBack"/>
        </xsl:with-param>
        <xsl:with-param name="dirsLeft" as="xs:integer">
          <xsl:call-template name="countDirectoriesInPath">
            <xsl:with-param name="path" select="concat($PATHTOMAP,$pathFromMaplist)"/>
          </xsl:call-template>
        </xsl:with-param>
        <xsl:with-param name="remainingPath" select="concat($PATHTOMAP, $pathFromMaplist)"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="pathWithoutRelPaths">
      <!-- Path from the common ancestor, to the target file -->
      <xsl:call-template name="removeRelPaths">
        <xsl:with-param name="path" select="$path"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="backToCommon">
      <!-- Path from the target file, to the common ancestor -->
      <xsl:call-template name="pathBackToMapDirectory">
        <xsl:with-param name="path" select="$pathWithoutRelPaths"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- Now, to get from the target file to any other: it must go up until it hits the common dir.
       Then, it must travel back to the base directory containing the map. At that point, this
       path can be placed in front of any referenced topic, and it will get us to the right spot. -->
    <xsl:value-of select="concat($backToCommon, $moveToBase)"/>
  </xsl:template>  
  
  <!-- Count the number of paths removed from the base (1 for each ../ at the start of the href) -->
  <xsl:template name="countRelpaths" as="xs:integer">
    <xsl:param name="path" as="xs:string"/>
    <xsl:param name="currentCount" as="xs:integer" select="0"/>
    <xsl:choose>
      <xsl:when test="starts-with($path,'../')">
        <xsl:call-template name="countRelpaths">
          <xsl:with-param name="path" select="substring-after($path,'../')"/>
          <xsl:with-param name="currentCount" select="$currentCount + 1"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$currentCount"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Get the path from the common ancestor to the basedir of the input map -->
  <xsl:template name="MoveBackToBase" as="xs:string">
    <xsl:param name="saveDirs" as="xs:integer"/>
    <xsl:param name="dirsLeft" as="xs:integer" select="$DIRS-IN-MAP-PATH"/>
    <xsl:param name="remainingPath" select="$PATHTOMAP" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$saveDirs >= $dirsLeft">
        <xsl:value-of select="$remainingPath"/>
      </xsl:when>
      <xsl:when test="contains($remainingPath,'/')">
        <xsl:call-template name="MoveBackToBase">
          <xsl:with-param name="saveDirs" select="$saveDirs"/>
          <xsl:with-param name="dirsLeft" select="$dirsLeft - 1"/>
          <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'/')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$remainingPath"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>  
  
  <!-- Remove the ../ relpaths from the start of a path. The remainder can then be evaluated. -->
  <xsl:template name="removeRelPaths" as="xs:string">
    <xsl:param name="path" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="starts-with($path,'../')">
        <xsl:call-template name="removeRelPaths">
          <xsl:with-param name="path" select="substring-after($path,'../')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$path"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Do nothing when meet the title -->
  <xsl:template match="*[contains(@class, ' topic/title ')]"/>
  
  <xsl:template name="get-file-uri">
    <xsl:param name="href" as="xs:string"/>
    <xsl:param name="file-prefix" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="contains($href,'#')">
        <xsl:value-of select="concat($file-prefix,substring-before($href,'#'))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($file-prefix,$href)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="dita-ot:hasHrefOrLinktext" as="xs:boolean">
    <xsl:param name="el" as="element()"/>
    <xsl:sequence
      select="
        (
          ($el/@href and not($el/@href = '')) or
          $el/*/*[contains(@class, ' map/linktext ') or contains(@class, ' topic/linktext ')]
        ) and
        not($el/@linking = ('none', 'sourceonly'))"
    />
  </xsl:function>
  
</xsl:stylesheet>
