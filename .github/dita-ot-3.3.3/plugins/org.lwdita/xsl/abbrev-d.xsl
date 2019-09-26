<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                exclude-result-prefixes="ditamsg">


  <xsl:template match="*[contains(@class,' abbrev-d/abbreviated-form ')]" name="topic.abbreviated-form">
    <xsl:if test="@keyref and @href">
      <xsl:variable name="entry-file" select="concat($WORKDIR, $PATH2PROJ, @href)"/>
      <xsl:variable name="entry-file-contents" select="document($entry-file, /)"/>
      <xsl:choose>
        <xsl:when test="$entry-file-contents//*[contains(@class,' glossentry/glossentry ')]">
          <!-- Fall back to process with normal term rules -->
          <xsl:call-template name="topic.term"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- TODO: Throw a warning for incorrect usage of <abbreviated-form> -->
          <xsl:apply-templates select="." mode="ditamsg:no-glossentry-for-abbreviated-form">
            <xsl:with-param name="keys" select="@keyref"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="ditamsg:no-glossentry-for-abbreviated-form">
    <xsl:param name="keys"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id">DOTX060W</xsl:with-param>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$keys"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
