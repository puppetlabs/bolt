<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2013 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">
  
  <xsl:output method="text"/>
  
  <xsl:param name="property"/>
  
  <xsl:template match="/">
    <xsl:variable name="prop" select="job/property[@name = $property]"/>
    <xsl:choose>
      <xsl:when test="$prop">
        <xsl:apply-templates select="$prop/*"/>
      </xsl:when>
      <xsl:when test="$property = 'canditopicslist'">
        <xsl:apply-templates select="job/files/file[@non-conref-target = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'codereflist'">
        <xsl:apply-templates select="job/files/file[@has-coderef = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'conreflist'">
        <xsl:apply-templates select="job/files/file[@has-conref = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'conrefpushlist'">
        <xsl:apply-templates select="job/files/file[@conrefpush = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'conreftargetslist'">
        <xsl:apply-templates select="job/files/file[@conref-target = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'copytosourcelist'">
        <xsl:apply-templates select="job/files/file[@copy-to-source = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'flagimagelist'">
        <xsl:apply-templates select="job/files/file[@flag-image = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'fullditamaplist'">
        <xsl:apply-templates select="job/files/file[@format = 'ditamap']"/>
      </xsl:when>
      <xsl:when test="$property = 'fullditamapandtopiclist'">
        <xsl:apply-templates select="job/files/file[(@format = 'ditamap' or @format = 'dita')]"/>
      </xsl:when>
      <xsl:when test="$property = 'fullditatopiclist'">
        <xsl:apply-templates select="job/files/file[@format = 'dita']"/>
      </xsl:when>
      <xsl:when test="$property = 'hrefditatopiclist'">
        <xsl:apply-templates select="job/files/file[@has-link = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'hreftargetslist'">
        <xsl:apply-templates select="job/files/file[@target = 'true']"/>
      </xsl:when>
      <!-- Deprecated since 2.2 -->
      <xsl:when test="$property = 'htmllist'">
        <xsl:apply-templates select="job/files/file[@format = 'html']"/>
      </xsl:when>
      <!-- Deprecated since 2.2 -->
      <xsl:when test="$property = 'imagelist'">
        <xsl:apply-templates select="job/files/file[@format = 'image']"/>
      </xsl:when>
      <xsl:when test="$property = 'keyreflist'">
        <xsl:apply-templates select="job/files/file[@has-keyref = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'outditafileslist'">
        <xsl:apply-templates select="job/files/file[@out-dita = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'resourceonlylist'">
        <xsl:apply-templates select="job/files/file[@resource-only = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'subjectschemelist'">
        <xsl:apply-templates select="job/files/file[@subjectscheme = 'true']"/>
      </xsl:when>
      <xsl:when test="$property = 'subtargetslist'">
        <xsl:apply-templates select="job/files/file[@subtarget = 'true']"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">ERROR: Unrecognized property '<xsl:value-of select="$property"/>'</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>
  
  <xsl:template match="set">
    <xsl:for-each select="string">
      <xsl:if test="not(position() = 1)"><xsl:text>&#xA;</xsl:text></xsl:if>
      <xsl:apply-templates select="."/>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="string">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="file">
    <xsl:if test="not(position() = 1)"><xsl:text>&#xA;</xsl:text></xsl:if>
    <xsl:value-of select="@path"/>
  </xsl:template>
  
</xsl:stylesheet>
