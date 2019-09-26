<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

  <xsl:template match="*[contains(@class, ' markup-d/markupname ')]">
    <code>
      <xsl:call-template name="commonattributes"/>
      <xsl:text>&lt;</xsl:text>
      <xsl:apply-templates/>
      <xsl:text>&gt;</xsl:text>
    </code>
  </xsl:template>
  
</xsl:stylesheet>
