<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg" version="2.0"
                exclude-result-prefixes="dita-ot ditamsg">

  <xsl:variable name="msgprefix">DOTX</xsl:variable>

  <xsl:param name="OUTEXT" select="'.html'"/>
  <xsl:param name="WORKDIR">
    <xsl:apply-templates select="/processing-instruction('workdir-uri')[1]" mode="get-work-dir"/>
  </xsl:param>
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="toc">
    <xsl:param name="pathFromMaplist"/>
    <xsl:if test="descendant::*[contains(@class, ' map/topicref ')]
                               [not(@toc = 'no')]
                               [not(@processing-role = 'resource-only')]">
      <bulletlist>
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
          <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
        </xsl:apply-templates>
      </bulletlist>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' map/topicref ')]
                        [not(@toc = 'no')]
                        [not(@processing-role = 'resource-only')]"
                mode="toc">
    <xsl:param name="pathFromMaplist"/>
    <xsl:variable name="title">
      <xsl:apply-templates select="." mode="get-navtitle"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="normalize-space($title)">
        <li>
          <xsl:call-template name="commonattributes"/>
          <xsl:choose>
            <!-- If there is a reference to a DITA or HTML file, and it is not external: -->
            <xsl:when test="normalize-space(@href)">
              <link>
                <xsl:attribute name="href">
                  <xsl:choose>
                    <xsl:when test="@copy-to and not(contains(@chunk, 'to-content')) and 
                                    (not(@format) or @format = 'dita' or @format = 'ditamap') ">
                      <xsl:if test="not(@scope = 'external')">
                        <xsl:value-of select="$pathFromMaplist"/>
                      </xsl:if>
                      <xsl:call-template name="replace-extension">
                        <xsl:with-param name="filename" select="@copy-to"/>
                        <xsl:with-param name="extension" select="$OUTEXT"/>
                      </xsl:call-template>
                      <xsl:if test="not(contains(@copy-to, '#')) and contains(@href, '#')">
                        <xsl:value-of select="concat('#', substring-after(@href, '#'))"/>
                      </xsl:if>
                    </xsl:when>
                    <xsl:when test="not(@scope = 'external') and (not(@format) or @format = 'dita' or @format = 'ditamap')">
                      <xsl:if test="not(@scope = 'external')">
                        <xsl:value-of select="$pathFromMaplist"/>
                      </xsl:if>
                      <xsl:call-template name="replace-extension">
                        <xsl:with-param name="filename" select="@href"/>
                        <xsl:with-param name="extension" select="$OUTEXT"/>
                      </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise><!-- If non-DITA, keep the href as-is -->
                      <xsl:if test="not(@scope = 'external')">
                        <xsl:value-of select="$pathFromMaplist"/>
                      </xsl:if>
                      <xsl:value-of select="@href"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:attribute>
                <!--xsl:if test="@scope = 'external' or not(not(@format) or @format = 'dita' or @format = 'ditamap')">
                  <xsl:attribute name="target">_blank</xsl:attribute>
                </xsl:if-->
                <xsl:value-of select="$title"/>
              </link>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$title"/>
            </xsl:otherwise>
          </xsl:choose>
          <!-- If there are any children that should be in the TOC, process them -->
          <xsl:if test="descendant::*[contains(@class, ' map/topicref ')]
                                     [not(@toc = 'no')]
                                     [not(@processing-role = 'resource-only')]">
            <bulletlist>
              <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
                <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
              </xsl:apply-templates>
            </bulletlist>
          </xsl:if>
        </li>
      </xsl:when>
      <xsl:otherwise><!-- if it is an empty topicref -->
        <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
          <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- If toc=no, but a child has toc=yes, that child should bubble up to the top -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]
                        [@toc = 'no']
                        [not(@processing-role = 'resource-only')]"
                mode="toc">
    <xsl:param name="pathFromMaplist"/>
    <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
      <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*" mode="toc" priority="-1"/>

  <xsl:template match="*" mode="get-navtitle">
    <xsl:choose>
      <!-- If navtitle is specified -->
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]"
                             mode="dita-ot:text-only"/>
      </xsl:when>
      <xsl:when test="@navtitle">
        <xsl:value-of select="@navtitle"/>
      </xsl:when>
      <!-- If there is no title and none can be retrieved, check for <linktext> -->
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]">
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]"
                             mode="dita-ot:text-only"/>
      </xsl:when>
      <!-- No local title, and not targeting a DITA file. Could be just a container setting
           metadata, or a file reference with no title. Issue message for the second case. -->
      <xsl:otherwise>
        <xsl:if test="normalize-space(@href)">
          <xsl:apply-templates select="." mode="ditamsg:could-not-retrieve-navtitle-using-fallback">
            <xsl:with-param name="target" select="@href"/>
            <xsl:with-param name="fallback" select="@href"/>
          </xsl:apply-templates>
          <xsl:value-of select="@href"/>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="ditamsg:missing-target-file-no-navtitle">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id">DOTX008W</xsl:with-param>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*" mode="ditamsg:could-not-retrieve-navtitle-using-fallback">
    <xsl:param name="target"/>
    <xsl:param name="fallback"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id">DOTX009W</xsl:with-param>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$target"/>;%2=<xsl:value-of select="$fallback"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
