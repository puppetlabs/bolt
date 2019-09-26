<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0"
                exclude-result-prefixes="related-links xs">

  <xsl:template match="*[contains(@class, ' topic/link ')][@type='concept']" mode="related-links:get-group"
                name="related-links:group.concept"
                as="xs:string">
    <xsl:text>concept</xsl:text>
  </xsl:template>
    
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='concept']" mode="related-links:get-group-priority"
                name="related-links:group-priority.concept"
                as="xs:integer">
    <xsl:sequence select="3"/>
  </xsl:template>
    
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='concept']" mode="related-links:result-group"
                name="related-links:result.concept"
                as="element(linklist)">
    <xsl:param name="links" as="node()*"/>
    <xsl:if test="normalize-space(string-join($links, ''))">
      <linklist class="- topic/linklist " outputclass="relinfo relconcepts">
        <title class="- topic/title ">
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related concepts'"/>
        </xsl:call-template>
          </title>
          <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>
    
</xsl:stylesheet>