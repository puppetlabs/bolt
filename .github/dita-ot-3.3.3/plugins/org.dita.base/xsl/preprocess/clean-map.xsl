<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2014 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0"
                exclude-result-prefixes="xs">
  
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>

  <!-- Deprecated since 2.3 -->
  <xsl:variable name="msgprefix">DOTX</xsl:variable>
  
  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' ditaot-d/submap ')]">
    <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' ditaot-d/submap-title ')]"/>
  <xsl:template match="*[contains(@class, ' ditaot-d/submap-topicmeta ')]"/>
  <xsl:template match="*[contains(@class, ' ditaot-d/submap-topicmeta-container ')]"/>
  
  <xsl:template match="*[contains(@class, ' ditaot-d/keydef ')]"/>
  
  <xsl:template match="*[contains(@class, ' mapgroup-d/topicgroup ')]/*/*[contains(@class, ' topic/navtitle ')]">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX072I'"/>
    </xsl:call-template>
  </xsl:template>
  
</xsl:stylesheet>
