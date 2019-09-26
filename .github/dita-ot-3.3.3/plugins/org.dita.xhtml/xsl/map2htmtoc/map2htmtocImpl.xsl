<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                exclude-result-prefixes="dita-ot ditamsg">

<!-- *************************** Command line parameters *********************** -->
<xsl:param name="contenttarget" select="'contentwin'"/>
<xsl:param name="CSS"/>
<xsl:param name="CSSPATH"/>
<xsl:param name="OUTPUTCLASS"/>   <!-- class to put on body element. -->
<!-- the path back to the project. Used for c.gif, delta.gif, css to allow user's to have
  these files in 1 location. -->
<xsl:param name="PATH2PROJ">
  <xsl:apply-templates select="/processing-instruction('path2project-uri')[1]" mode="get-path2project"/>
</xsl:param>
<xsl:param name="genDefMeta" select="'no'"/>
<xsl:param name="YEAR" select="format-date(current-date(), '[Y]')"/>
<!-- Define a newline character -->
<xsl:variable name="newline"><xsl:text>
</xsl:text></xsl:variable>

<!-- *********************************************************************************
     Setup the HTML wrapper for the table of contents
     ********************************************************************************* -->
  <xsl:template match="/">
    <xsl:call-template name="generate-toc"/>
  </xsl:template>
<!--  -->
<xsl:template name="generate-toc">
  <html><xsl:value-of select="$newline"/>
  <head><xsl:value-of select="$newline"/>
    <xsl:if test="string-length($contenttarget)>0 and
          $contenttarget!='NONE'">
      <base target="{$contenttarget}"/>
      <xsl:value-of select="$newline"/>
    </xsl:if>
    <!-- initial meta information -->
    <xsl:call-template name="generateCharset"/>   <!-- Set the character set to UTF-8 -->
    <xsl:call-template name="generateDefaultCopyright"/> <!-- Generate a default copyright, if needed -->
    <xsl:call-template name="generateDefaultMeta"/> <!-- Standard meta for security, robots, etc -->
    <xsl:call-template name="copyright"/>         <!-- Generate copyright, if specified manually -->
    <xsl:call-template name="generateCssLinks"/>  <!-- Generate links to CSS files -->
    <xsl:call-template name="generateMapTitle"/> <!-- Generate the <title> element -->
    <xsl:call-template name="gen-user-head" />    <!-- include user's XSL HEAD processing here -->
    <xsl:call-template name="gen-user-scripts" /> <!-- include user's XSL javascripts here -->
    <xsl:call-template name="gen-user-styles" />  <!-- include user's XSL style element and content here -->
  </head><xsl:value-of select="$newline"/>

  <body>
     <xsl:if test="string-length($OUTPUTCLASS) &gt; 0">
       <xsl:attribute name="class">
         <xsl:value-of select="$OUTPUTCLASS"/>
       </xsl:attribute>
     </xsl:if>
     <xsl:value-of select="$newline"/>
    <xsl:apply-templates mode="toc"/>
   </body><xsl:value-of select="$newline"/>
  </html>
</xsl:template>

<xsl:template name="generateCharset">
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/><xsl:value-of select="$newline"/>
</xsl:template>

<!-- If there is no copyright in the document, make the standard one -->
<xsl:template name="generateDefaultCopyright">
  <xsl:if test="not(//*[contains(@class,' topic/copyright ')])">
    <meta name="copyright">
      <xsl:attribute name="content">
        <xsl:text>(C) </xsl:text>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Copyright'"/>
        </xsl:call-template>
        <xsl:text> </xsl:text><xsl:value-of select="$YEAR"/>
      </xsl:attribute>
    </meta>
    <xsl:value-of select="$newline"/>
    <meta name="DC.rights.owner">
      <xsl:attribute name="content">
        <xsl:text>(C) </xsl:text>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Copyright'"/>
        </xsl:call-template>
        <xsl:text> </xsl:text><xsl:value-of select="$YEAR"/>
      </xsl:attribute>
    </meta>
    <xsl:value-of select="$newline"/>
  </xsl:if>
</xsl:template>

<xsl:template name="generateDefaultMeta">
  <xsl:if test="$genDefMeta = 'yes'">
    <meta name="security" content="public" /><xsl:value-of select="$newline"/>
    <meta name="Robots" content="index,follow" /><xsl:value-of select="$newline"/>
    <xsl:text disable-output-escaping="yes">&lt;meta http-equiv="PICS-Label" content = '(PICS-1.1 "http://www.icra.org/ratingsv02.html" l gen true r (cz 1 lz 1 nz 1 oz 1 vz 1) "http://www.rsac.org/ratingsv01.html" l gen true r (n 0 s 0 v 0 l 0) "http://www.classify.org/safesurf/" l gen true r (SS~~000 1))' /></xsl:text>
    <xsl:value-of select="$newline"/>
  </xsl:if>
</xsl:template>

<xsl:template name="copyright">
  
</xsl:template>

<xsl:template name="generateMapTitle">
  <!-- Title processing - special handling for short descriptions -->
  <xsl:if test="/*[contains(@class,' map/map ')]/*[contains(@class,' topic/title ')] or /*[contains(@class,' map/map ')]/@title">
  <title>
    <xsl:call-template name="gen-user-panel-title-pfx"/> <!-- hook for a user-XSL title prefix -->
    <xsl:choose>
      <xsl:when test="/*[contains(@class,' map/map ')]/*[contains(@class,' topic/title ')]">
        <xsl:value-of select="normalize-space(/*[contains(@class,' map/map ')]/*[contains(@class,' topic/title ')])"/>
      </xsl:when>
      <xsl:when test="/*[contains(@class,' map/map ')]/@title">
        <xsl:value-of select="/*[contains(@class,' map/map ')]/@title"/>
      </xsl:when>
    </xsl:choose>
  </title><xsl:value-of select="$newline"/>
  </xsl:if>
</xsl:template>

<xsl:template name="gen-user-panel-title-pfx">
  <xsl:apply-templates select="." mode="gen-user-panel-title-pfx"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-panel-title-pfx">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed immediately after TITLE tag, in the title -->
</xsl:template>

<!-- Link to user CSS. -->
<!-- Test for URL: returns "url" when the content starts with a URL;
  Otherwise, leave blank -->
<xsl:template name="url-string">
  <xsl:param name="urltext"/>
  <xsl:choose>
    <xsl:when test="starts-with($urltext,'http://')">url</xsl:when>
    <xsl:when test="starts-with($urltext,'https://')">url</xsl:when>
    <xsl:otherwise/>
  </xsl:choose>
</xsl:template>

<!-- Can't link to commonltr.css or commonrtl.css because we don't know what language the map is in. -->
<xsl:template name="generateCssLinks">
  <xsl:variable name="urltest">
    <xsl:call-template name="url-string">
      <xsl:with-param name="urltext">
        <xsl:value-of select="concat($CSSPATH,$CSS)"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:variable>
  <xsl:if test="string-length($CSS)>0">
  <xsl:choose>
    <xsl:when test="$urltest = 'url'">
      <link rel="stylesheet" type="text/css" href="{$CSSPATH}{$CSS}" />
    </xsl:when>
    <xsl:otherwise>
      <link rel="stylesheet" type="text/css" href="{$PATH2PROJ}{$CSSPATH}{$CSS}" />
    </xsl:otherwise>
  </xsl:choose><xsl:value-of select="$newline"/>   
  </xsl:if>
</xsl:template>

<!-- To be overridden by user shell. -->

<xsl:template name="gen-user-head">
  <xsl:apply-templates select="." mode="gen-user-head"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-head">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- it will be placed in the HEAD section of the XHTML. -->
</xsl:template>

<xsl:template name="gen-user-header">
  <xsl:apply-templates select="." mode="gen-user-header"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-header">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- it will be placed in the running heading section of the XHTML. -->
</xsl:template>

<xsl:template name="gen-user-footer">
  <xsl:apply-templates select="." mode="gen-user-footer"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-footer">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- it will be placed in the running footing section of the XHTML. -->
</xsl:template>

<xsl:template name="gen-user-sidetoc">
  <xsl:apply-templates select="." mode="gen-user-sidetoc"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-sidetoc">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- Uncomment the line below to have a "freebie" table of contents on the top-right -->
</xsl:template>

<xsl:template name="gen-user-scripts">
  <xsl:apply-templates select="." mode="gen-user-scripts"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-scripts">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed before the ending HEAD tag -->
  <!-- see (or enable) the named template "script-sample" for an example -->
</xsl:template>

<xsl:template name="gen-user-styles">
  <xsl:apply-templates select="." mode="gen-user-styles"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-styles">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed before the ending HEAD tag -->
</xsl:template>

<xsl:template name="gen-user-external-link">
  <xsl:apply-templates select="." mode="gen-user-external-link"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-external-link">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed after an external LINK or XREF -->
</xsl:template>

<!-- Template to get the relative path to a map -->
<xsl:template name="getRelativePath">
  <xsl:param name="remainingPath" select="@file"/>
  <xsl:choose>
    <xsl:when test="contains($remainingPath,'/')">
      <xsl:value-of select="substring-before($remainingPath,'/')"/><xsl:text>/</xsl:text>
      <xsl:call-template name="getRelativePath">
        <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'/')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="contains($remainingPath,'\')">
      <xsl:value-of select="substring-before($remainingPath,'\')"/><xsl:text>/</xsl:text>
      <xsl:call-template name="getRelativePath">
        <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'\')"/>
      </xsl:call-template>
    </xsl:when>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
