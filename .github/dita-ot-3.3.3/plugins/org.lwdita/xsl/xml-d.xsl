<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

  <xsl:template match="*[contains(@class, ' xml-d/xmlelement ')]">
    <code>
      <xsl:apply-templates/>
    </code>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' xml-d/xmlatt ')]">
    <code>
      <xsl:text>@</xsl:text>
      <xsl:apply-templates/>
    </code>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' xml-d/textentity ')]">
    <code>
      <xsl:text>&amp;</xsl:text>
      <xsl:apply-templates/>
      <xsl:text>;</xsl:text>
    </code>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' xml-d/parameterentity ')]">
    <code>
      <xsl:text>%</xsl:text>
      <xsl:apply-templates/>
      <xsl:text>;</xsl:text>
    </code>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' xml-d/numcharref ')]">
    <code>
      <xsl:text>&amp;#</xsl:text>
      <xsl:apply-templates/>
      <xsl:text>;</xsl:text>
    </code>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' xml-d/xmlnsname ')]">
    <code>
      <xsl:apply-templates/>
    </code>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' xml-d/xmlpi ')]">
    <code>
      <xsl:apply-templates/>
    </code>
  </xsl:template>

</xsl:stylesheet>
