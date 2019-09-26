<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:fn="http://example.com/namespace"
                exclude-result-prefixes="xs fn"
                version="2.0">

  <xsl:output method="text"/>
  <xsl:strip-space elements="*"/>

  <xsl:variable name="wrapCol" select="80"/>
  <xsl:variable name="indentSize" select="20"/>

  <xsl:variable name="crlf" select="codepoints-to-string((13,10))"/>
  <xsl:variable name="comment" select="concat($crlf,'# ')"/>
  <xsl:variable name="divBar" select="concat('# ',fn:padIt('=',$wrapCol - 4),' #')"/>
  <xsl:variable name="sctn-start" select="concat($crlf,$crlf,'##### ')"/>
  <xsl:variable name="sctn-end" select="concat(' PROPERTIES #####',$crlf)"/>
  <xsl:variable name="indentSpaces" select="fn:padIt(' ',$indentSize)"/>

  <xsl:function name="fn:padIt" as="xs:string">
    <xsl:param name="string" as="xs:string"/>
    <xsl:param name="len" as="xs:integer"/>
    <xsl:variable name="seq">
      <xsl:for-each select="1 to $len">
        <xsl:value-of select="$string"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:value-of select="string-join($seq,'')"/>
  </xsl:function>

  <xsl:function name="fn:breakAfter">
    <xsl:param name="string" as="xs:string"/>
    <xsl:param name="breakpoint" as="xs:integer"/>
    <xsl:variable name="matchExpr" select="concat('^.{1,',$breakpoint,'}(\s|$)')"/>
    <xsl:variable name="rest" select="replace($string,$matchExpr,'')"/>
    <xsl:variable name="start" select="substring-before($string,$rest)"/>
    <xsl:choose>
      <xsl:when test="$start=''">
        <start><xsl:value-of select="$string"/></start>
        <rest></rest>
      </xsl:when>
      <xsl:otherwise>
        <start><xsl:value-of select="$start"/></start>
        <rest><xsl:value-of select="$rest"/></rest>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="fn:wrapAndIndent" as="xs:string">
    <xsl:param name="name" as="xs:string"/>
    <xsl:param name="description" as="xs:string"/>

    <xsl:variable name="step1"
      select="fn:breakAfter(concat(normalize-space($name),$indentSpaces,normalize-space($description)),$indentSize - 1)"/>
    <xsl:variable name="step2"
      select="fn:breakAfter(concat($step1[1],normalize-space($step1[2])),$wrapCol)"/>

    <xsl:choose>
      <xsl:when test="string-length($step2[2]) gt 0">
        <xsl:value-of select="concat($comment,$step2[1],fn:wrapAndIndent('',$step2[2]))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($comment,$step2[1])"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="/">
    <xsl:call-template name="all"/>
  </xsl:template>

  <xsl:template name="all">
    <xsl:text>
# ============================================================================ #
#
#   GENERATED PROPERTIES FILE FOR USE WITH THE DITA COMMAND
#
#   Lines in this file that start with a number sign '#' are comments.
#
#   To set a build parameter, remove the commenting '#' at the start of the line
#   and specify the value for the parameter after the '=' sign, for example,
#
#   args.filter = my-filter.ditaval
#
#   Use the `dita` command with the `--propertyfile` option to use the build
#   parameters specified in a properties file, for example:
#
#   dita --input=my.ditamap --format=html5 --propertyfile=my.properties
#
#   Build parameters in this file are grouped by transformation type.
#   Supported parameter values are listed in brackets [] after each description,
#   with an asterisk (*) indicating the default value where appropriate.
#
# ============================================================================ #
</xsl:text>
    <xsl:for-each-group select="//transtype[param]" group-by="@desc">
      <xsl:sort select="@desc"/>
      <xsl:variable name="padsize" select="(ceiling( (($wrapCol - string-length(@desc)) div 2 ) ) - 2) cast as xs:integer"/>
      <xsl:variable name="descpad" select="fn:padIt(' ',$padsize)"/>
      <xsl:value-of
        select="upper-case(concat($crlf,$crlf,$divBar,$crlf,'#',$descpad,@desc,$crlf,$divBar))"/>
      <xsl:for-each-group select="current-group()/param" group-by="@name">
        <xsl:sort select="@name"/>
        <xsl:call-template name="param"/>
      </xsl:for-each-group>
    </xsl:for-each-group>
  </xsl:template>

  <xsl:template name="param">
    <xsl:param name="params" select="current-group()"/>
    <xsl:param name="desc_pre" as="xs:string*">
      <xsl:if test="@required = 'true'">(REQUIRED) </xsl:if>
    </xsl:param>
    <xsl:param name="desc_post" as="xs:string*">
      <xsl:if test="not(./@type = 'enum') and $params/val/@default='true'">
        <xsl:value-of select="concat(' Default value: ',distinct-values($params/val[@default='true']),'.')"/>
      </xsl:if>
    </xsl:param>
    <xsl:choose>
      <xsl:when test="@name = 'args.input' or @name = 'transtype' or @deprecated = 'true'">
        <!-- don’t output these as they shouldn’t be used in properties file -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="exampleval">
          <xsl:choose>
            <xsl:when test="$params/val/@default='true'">
              <xsl:value-of select="distinct-values($params/val[@default='true'])"/>
            </xsl:when>
            <xsl:when test="./@type = 'enum'">
              <xsl:value-of select="distinct-values($params/val[1])"/>
            </xsl:when>
            <xsl:otherwise></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="concat($crlf,$comment,@name,' = ',$exampleval)"/>
        <xsl:value-of select="fn:wrapAndIndent('',concat($desc_pre,@desc,$desc_post))"/>
        <xsl:choose>
          <xsl:when test="@type = 'enum' and $params/val">
            <xsl:for-each-group select="$params/val" group-by="text()">
              <xsl:sort select="current-grouping-key()"/>
              <xsl:choose>
                <xsl:when test="@desc and @default = 'true'">
                  <xsl:value-of select="fn:wrapAndIndent('',concat('[ ',.,' ]* - ',@desc))"/>
                </xsl:when>
                <xsl:when test="@desc">
                  <xsl:value-of select="fn:wrapAndIndent('',concat('[ ',.,' ] - ',@desc))"/>
                </xsl:when>
                <xsl:when test="@default='true'">
                  <xsl:value-of select="fn:wrapAndIndent('',concat('[ ',.,' ]*'))"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="fn:wrapAndIndent('',concat('[ ',.,' ]'))"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:for-each-group>
          </xsl:when>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
