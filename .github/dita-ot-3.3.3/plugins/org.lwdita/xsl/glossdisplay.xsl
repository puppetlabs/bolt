<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
                version="2.0"
                exclude-result-prefixes="related-links">

  <xsl:template match="*[contains(@class, ' topic/link ')][@type='glossentry']" mode="related-links:get-group"
                name="related-links:group.glossentry">
    <xsl:call-template name="related-links:group.concept"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='glossentry']" mode="related-links:get-group-priority"
                name="related-links:group-priority.glossentry">
    <xsl:call-template name="related-links:group-priority.concept"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='glossentry']" mode="related-links:result-group"
                name="related-links:result.glossentry">
    <xsl:param name="links"/>
    <xsl:call-template name="related-links:result.concept">
      <xsl:with-param name="links" select="$links"/>
    </xsl:call-template>
  </xsl:template>
  
</xsl:stylesheet>
