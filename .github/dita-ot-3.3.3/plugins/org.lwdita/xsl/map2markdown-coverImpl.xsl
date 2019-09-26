<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                version="2.0"
                exclude-result-prefixes="xs dita-ot">

  <xsl:import href="map2markdownImpl.xsl"/>

  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:apply-templates select="." mode="root_element"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/map ')]" mode="chapterBody">
    
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
      <xsl:if test="@outputclass">
        <xsl:attribute name="class" select="@outputclass"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="addAttributesToBody"/>
      
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>

      <xsl:choose>
        <xsl:when test="*[contains(@class, ' topic/title ')]">
          <xsl:apply-templates select="*[contains(@class, ' topic/title ')]"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="@title"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="." mode="toc"/>
      <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/map ')]/*[contains(@class, ' topic/title ')]">
    <header level="1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:apply-templates/>
    </header>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/map ')]/@title">
    <header level="1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:value-of select="."/>
    </header>
  </xsl:template>

  <xsl:template match="*[contains(@class,' bookmap/bookmap ')]/*[contains(@class,' bookmap/booktitle ')]" priority="10">
    <header level="1">
      <xsl:call-template name="gen-user-panel-title-pfx"/>
      <xsl:apply-templates select="*[contains(@class, ' bookmap/mainbooktitle ')]/node()"/>
    </header>
  </xsl:template>

  <!--xsl:template name="generateChapterTitle">
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
  </xsl:template-->

</xsl:stylesheet>
