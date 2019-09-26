<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2014 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0"
                exclude-result-prefixes="xs dita-ot">

  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:apply-templates select="." mode="root_element"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/map ')]" mode="chapterBody">
    <body>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
      <xsl:if test="@outputclass">
        <xsl:attribute name="class" select="@outputclass"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="addAttributesToBody"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:call-template name="generateBreadcrumbs"/>
      <xsl:call-template name="gen-user-header"/>
      <xsl:call-template name="processHDR"/>
      <xsl:if test="$INDEXSHOW = 'yes'">
        <xsl:apply-templates select="/*/*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/keywords ')]/*[contains(@class, ' topic/indexterm ')]"/>
      </xsl:if>
      <xsl:call-template name="gen-user-sidetoc"/>
      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/title ')]">
          <xsl:apply-templates select="*[contains(@class, ' topic/title ')]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="@title"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:variable name="map" as="element()*">
        <xsl:apply-templates select="." mode="normalize-map"/>
      </xsl:variable>
      <xsl:apply-templates select="$map" mode="toc"/>
      <xsl:call-template name="gen-endnotes"/>
      <xsl:call-template name="gen-user-footer"/>
      <xsl:call-template name="processFTR"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </body>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/map ')]/*[contains(@class, ' topic/title ')]">
    <h1 class="title topictitle1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:apply-templates/>
    </h1>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/map ')]/@title">
    <h1 class="title topictitle1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:value-of select="."/>
    </h1>
  </xsl:template>

  <xsl:template match="*[contains(@class,' bookmap/bookmap ')]/*[contains(@class,' bookmap/booktitle ')]" priority="10">
    <h1 class="title topictitle1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:apply-templates select="*[contains(@class, ' bookmap/mainbooktitle ')]/node()"/>
    </h1>
  </xsl:template>

  <xsl:template name="generateChapterTitle">
    <title>
      <xsl:choose>
        <xsl:when test="/*[contains(@class,' bookmap/bookmap ')]/*[contains(@class,' bookmap/booktitle ')]/*[contains(@class, ' bookmap/mainbooktitle ')]">
          <xsl:call-template name="gen-user-panel-title-pfx"/>
          <xsl:value-of select="/*[contains(@class,' bookmap/bookmap ')]/*[contains(@class,' bookmap/booktitle ')]/*[contains(@class, ' bookmap/mainbooktitle ')]"/>
        </xsl:when>
        <xsl:when test="/*[contains(@class,' map/map ')]/*[contains(@class,' topic/title ')]">
          <xsl:call-template name="gen-user-panel-title-pfx"/>
          <xsl:value-of select="/*[contains(@class,' map/map ')]/*[contains(@class,' topic/title ')]"/>
        </xsl:when>
        <xsl:when test="/*[contains(@class,' map/map ')]/@title">
          <xsl:call-template name="gen-user-panel-title-pfx"/>
          <xsl:value-of select="/*[contains(@class,' map/map ')]/@title"/>
        </xsl:when>
      </xsl:choose>
    </title>
  </xsl:template>

</xsl:stylesheet>
