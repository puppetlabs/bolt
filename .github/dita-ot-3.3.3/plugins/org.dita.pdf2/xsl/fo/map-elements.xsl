<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2012 Eero Helenius

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  version="2.0">

  <xsl:template match="*[contains(@class,' map/topicmeta ')]/*[contains(@class,' map/searchtitle ')]"/>

  <xsl:template match="*[contains(@class, ' map/topicmeta ')]">
    <!--
    <fo:block xsl:use-attribute-sets="topicmeta">
      <xsl:apply-templates/>
    </fo:block>
    -->
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/map ')]/*[contains(@class, ' map/reltable ')]">
    <fo:table-and-caption>
      <fo:table-caption>
        <fo:block xsl:use-attribute-sets="reltable__title">
          <xsl:value-of select="@title"/>
        </fo:block>
      </fo:table-caption>

      <fo:table xsl:use-attribute-sets="reltable">
        <xsl:call-template name="topicrefAttsNoToc"/>
        <xsl:call-template name="selectAtts"/>
        <xsl:call-template name="globalAtts"/>
        <xsl:apply-templates select="relheader"/>
        <fo:table-body>
          <xsl:apply-templates select="relrow"/>
        </fo:table-body>
      </fo:table>
    </fo:table-and-caption>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/relheader ')]">
    <fo:table-header xsl:use-attribute-sets="relheader">
      <xsl:call-template name="globalAtts"/>
      <xsl:apply-templates/>
    </fo:table-header>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/relcolspec ')]">
    <fo:table-cell xsl:use-attribute-sets="relcolspec">
      <xsl:apply-templates/>
    </fo:table-cell>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/relrow ')]">
    <fo:table-row xsl:use-attribute-sets="relrow">
      <xsl:call-template name="globalAtts"/>
      <xsl:apply-templates/>
    </fo:table-row>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/relcell ')]">
    <fo:table-cell xsl:use-attribute-sets="relcell">
      <xsl:call-template name="globalAtts"/>
      <xsl:call-template name="topicrefAtts"/>
      <xsl:apply-templates/>
    </fo:table-cell>
  </xsl:template>

</xsl:stylesheet>
