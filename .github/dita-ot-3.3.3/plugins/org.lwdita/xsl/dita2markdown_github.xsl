<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:import href="dita2markdown.xsl"/>
  
  <xsl:template name="ast-attibutes"/>

  <xsl:template match="*" mode="chapterHead">
    <xsl:call-template name="getMeta"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/dl ')]">
    <xsl:variable name="ul" as="document-node()">
      <xsl:document>
        <ul class="- topic/ul ">
          <xsl:for-each select="*[contains(@class, ' topic/dlentry ')]">
            <li class="- topic/li ">
              <b class="+ topic/ph hi-d/b ">
                <xsl:copy-of select="*[contains(@class, ' topic/dt ')]/node()"/>
              </b>
              <xsl:for-each select="*[contains(@class, ' topic/dd ')]">
                <p class="- topic/p ">
                  <xsl:copy-of select="node()"/>
                </p>
              </xsl:for-each>
            </li>
          </xsl:for-each>
        </ul>
      </xsl:document>
    </xsl:variable>
    <xsl:apply-templates select="$ul/node()"/>
  </xsl:template>
  
</xsl:stylesheet>
