<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                exclude-result-prefixes="xs">

  <xsl:import href="classpath:///hdita2dita-common.xsl"/>

  <xsl:output indent="yes"></xsl:output>

  <xsl:template match="/">
    <xsl:apply-templates select="html"/>
  </xsl:template>

  <xsl:template match="html">
    <xsl:choose>
      <xsl:when test="count(body/article) gt 1">
        <dita>
          <xsl:attribute name="ditaarch:DITAArchVersion">1.3</xsl:attribute>
          <xsl:apply-templates select="@* | node()"/>
        </dita>        
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="body"/>        
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
