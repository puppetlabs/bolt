<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

  <xsl:import href="map2markdown-cover.xsl"/>

  <xsl:template match="*[contains(@class, ' map/map ')]" mode="chapterBody">
    <header level="1">Summary</header>

    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:apply-templates select="." mode="toc"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>

</xsl:stylesheet>