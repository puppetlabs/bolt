<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ast="com.elovirta.dita.markdown"
                exclude-result-prefixes="xs ast"
                version="2.0">

  <xsl:variable name="linefeed" as="xs:string" select="'&#xA;'"/>

  <!-- Block -->

  <xsl:template match="pandoc" mode="ast">
    <xsl:apply-templates mode="ast"/>
  </xsl:template>

  <xsl:template match="div" mode="ast">
    <xsl:apply-templates mode="ast"/>
  </xsl:template>

  <xsl:template match="para" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:call-template name="process-inline-contents"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <xsl:template match="plain" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <!-- XXX; why is indent here? -->
    <xsl:value-of select="$indent"/>
    <xsl:call-template name="process-inline-contents"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:if test="parent::li and following-sibling::*[not(self::bulletlist | self::orderedlist)]">
      <xsl:value-of select="$linefeed"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="header" mode="ast">
    <xsl:for-each select="1 to xs:integer(@level)">#</xsl:for-each>
    <xsl:text> </xsl:text>
    <!--xsl:apply-templates mode="ast"/-->
    <xsl:call-template name="process-inline-contents"/>
    <xsl:call-template name="ast-attibutes"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>
  
  <xsl:template name="ast-attibutes">
    <xsl:if test="@id or @class">
      <xsl:text> {</xsl:text>
      <xsl:if test="@id">
        <xsl:text>#</xsl:text>
        <xsl:value-of select="@id"/>
      </xsl:if>
      <xsl:for-each select="tokenize(@class, '\s+')">
        <xsl:text> .</xsl:text>
        <xsl:value-of select="."/>
      </xsl:for-each>
      <xsl:text>}</xsl:text>
    </xsl:if>
  </xsl:template>

  <xsl:template match="bulletlist | orderedlist" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:variable name="nested" select="ancestor::bulletlist or ancestor::orderedlist"/>
    <xsl:variable name="lis" select="li"/>
    <xsl:apply-templates select="$lis" mode="ast"/>
    <xsl:if test="not($nested)">
      <xsl:value-of select="$linefeed"/><!-- because last li will not write one -->
    </xsl:if>  
  </xsl:template>

  <xsl:variable name="default-indent" select="'    '" as="xs:string"/>

  <xsl:template match="li" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:choose>
      <xsl:when test="parent::bulletlist">
        <xsl:text>-   </xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="label" select="concat(position(), '.')" as="xs:string"/>
        <xsl:value-of select="$label"/>
        <xsl:value-of select="substring($default-indent, string-length($label) + 1)"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="*[1]" mode="ast">
      <xsl:with-param name="indent" tunnel="yes" select="''"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="*[position() ne 1]" mode="ast">
      <xsl:with-param name="indent" tunnel="yes" select="concat($indent, $default-indent)"/>
    </xsl:apply-templates>
    <!--xsl:if test="following-sibling::li">
      <xsl:value-of select="$linefeed"/>
    </xsl:if-->
  </xsl:template>
  
  <xsl:template match="definitionlist" mode="ast">
    <xsl:apply-templates mode="ast"/>
  </xsl:template>

  <xsl:template match="dlentry" mode="ast">
    <xsl:apply-templates mode="ast"/>
  </xsl:template>

  <xsl:template match="dt" mode="ast">
    <xsl:call-template name="process-inline-contents"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>

  <xsl:template match="dd" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:text>:   </xsl:text>
    <xsl:apply-templates select="*[1]" mode="ast">
      <xsl:with-param name="indent" tunnel="yes" select="''"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="*[position() ne 1]" mode="ast">
      <xsl:with-param name="indent" tunnel="yes" select="concat($indent, $default-indent)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="codeblock" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:value-of select="$indent"/>
    <xsl:text>```</xsl:text>
    <xsl:choose>
      <xsl:when test="empty(@id) and @class and not(contains(@class, ' '))">
        <xsl:value-of select="@class"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="ast-attibutes"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$linefeed"/>
    <xsl:call-template name="process-inline-contents"/>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$indent"/>
    <xsl:text>```</xsl:text>
    <xsl:value-of select="$linefeed"/>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>
  
  <xsl:template match="blockquote" mode="ast">
    <xsl:param name="prefix" tunnel="yes" as="xs:string?" select="()"/>
    <xsl:apply-templates mode="ast">
      <xsl:with-param name="prefix" tunnel="yes" select="concat($prefix, '> ')"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template name="process-inline-contents">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:param name="prefix" tunnel="yes" as="xs:string?" select="()"/>
    <xsl:variable name="contents" as="xs:string">
      <xsl:value-of>
        <xsl:apply-templates mode="ast"/>
      </xsl:value-of>
    </xsl:variable>
    <xsl:variable name="idnt" select="if (ancestor-or-self::tablecell) then () else $indent" as="xs:string?"/>
    <xsl:for-each select="tokenize($contents, '\n')">
      <xsl:value-of select="$idnt"/>  
      <xsl:value-of select="$prefix"/>
      <xsl:value-of select="."/>
      <xsl:if test="position() ne last()">
        <xsl:value-of select="$linefeed"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="table" mode="ast">
    <xsl:param name="indent" tunnel="yes" as="xs:string" select="''"/>
    <xsl:for-each select="thead">
      <xsl:value-of select="$indent"/>
      <xsl:for-each select="tr">
        <xsl:text>|</xsl:text>
        <xsl:for-each select="tablecell">
          <xsl:call-template name="process-inline-contents"/>
          <xsl:text>|</xsl:text>
        </xsl:for-each>
        <xsl:value-of select="$linefeed"/>
      </xsl:for-each>
      <xsl:for-each select="tr">
        <xsl:value-of select="$indent"/>
        <xsl:text>|</xsl:text>
        <xsl:for-each select="tablecell">
          <xsl:variable name="colnum" as="xs:integer" select="position()"/>
          <xsl:variable name="align" select="ancestor::table[1]/col[$colnum]/@align"/>
          <xsl:variable name="content">
            <xsl:call-template name="process-inline-contents"/>
          </xsl:variable>
          <xsl:value-of select="if ($align = ('left', 'center')) then ':' else '-'"/>
          <xsl:for-each select="3 to string-length($content)">-</xsl:for-each>
          <xsl:value-of select="if ($align = ('right', 'center')) then ':' else '-'"/>
          <xsl:text>|</xsl:text>
        </xsl:for-each>
        <xsl:value-of select="$linefeed"/>
      </xsl:for-each>
    </xsl:for-each>
    <xsl:for-each select="tbody">
      <xsl:for-each select="tr">
        <xsl:value-of select="$indent"/>
        <xsl:text>|</xsl:text>
        <xsl:for-each select="tablecell">
          <!--xsl:apply-templates mode="ast"/-->
          <xsl:call-template name="process-inline-contents"/>
          <xsl:text>|</xsl:text>
        </xsl:for-each>
        <xsl:value-of select="$linefeed"/>
      </xsl:for-each>
    </xsl:for-each>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>
  
  <!-- Inline -->
  
  <xsl:template match="strong" mode="ast">
    <xsl:text>**</xsl:text>
    <xsl:apply-templates mode="ast"/>
    <xsl:text>**</xsl:text>
  </xsl:template>

  <xsl:template match="emph" mode="ast">
    <xsl:text>*</xsl:text>
    <xsl:apply-templates mode="ast"/>
    <xsl:text>*</xsl:text>
  </xsl:template>

  <xsl:template match="cite" mode="ast">
    <xsl:text>*</xsl:text>
    <xsl:apply-templates mode="ast"/>
    <xsl:text>*</xsl:text>
  </xsl:template>

  <xsl:template match="code" mode="ast">
    <xsl:text>`</xsl:text>
    <xsl:apply-templates mode="ast"/>
    <xsl:text>`</xsl:text>
  </xsl:template>

  <xsl:template match="link[empty(@href | @keyref)]" mode="ast">
    <xsl:apply-templates mode="ast"/>
  </xsl:template>

  <xsl:template match="link[@href]" mode="ast">
    <xsl:text>[</xsl:text>
    <xsl:apply-templates mode="ast"/>
    <xsl:text>]</xsl:text>
    <xsl:text>(</xsl:text>
    <xsl:value-of select="@href"/>
    <xsl:text>)</xsl:text>
  </xsl:template>
  
  <xsl:template match="link[empty(@href) and @keyref]" mode="ast">
    <xsl:text>[</xsl:text>
    <xsl:value-of select="@keyref"/>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
  <xsl:template match="image" mode="ast">
    <xsl:text>![</xsl:text>
    <xsl:value-of select="@alt"/>
    <xsl:apply-templates mode="ast"/>
    <xsl:text>]</xsl:text>
    <xsl:text>(</xsl:text>
    <xsl:value-of select="@href"/>
    <xsl:if test="@title">
      <xsl:text> "</xsl:text>
      <xsl:value-of select="@title"/>
      <xsl:text>"</xsl:text>
    </xsl:if>
    <xsl:text>)</xsl:text>
    <xsl:if test="@placement = 'break'">
      <xsl:value-of select="$linefeed"/>
      <xsl:value-of select="$linefeed"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="image[empty(@href) and @keyref]" mode="ast">
    <xsl:text>![</xsl:text>
    <xsl:value-of select="@keyref"/>
    <xsl:text>]</xsl:text>
  </xsl:template>

  <xsl:template match="span" mode="ast">
    <xsl:apply-templates mode="ast"/>
  </xsl:template>
  
  <xsl:template match="linebreak" mode="ast">
    <xsl:text>  </xsl:text>
    <xsl:value-of select="$linefeed"/>
  </xsl:template>
  
  <xsl:template match="text()" mode="ast"
                name="text">
    <xsl:param name="text" select="." as="xs:string"/>
    <xsl:variable name="head" select="substring($text, 1, 1)" as="xs:string"/>
    <xsl:if test="contains('\`*_{}[]()>#|', $head)"><!--{}+-.!-->
      <xsl:text>\</xsl:text>
    </xsl:if>
    <xsl:value-of select="$head"/>
    <xsl:variable name="tail" select="substring($text, 2)" as="xs:string"/>
    <xsl:if test="string-length($tail) gt 0">
      <xsl:call-template name="text">
        <xsl:with-param name="text" select="substring($text, 2)" as="xs:string"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="code/text() |
                       codeblock/text()"
                mode="ast" priority="10">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="node()" mode="ast" priority="-10">
    <xsl:message>ERROR: Unsupported AST node <xsl:value-of select="name()"/></xsl:message>
    <xsl:apply-templates mode="ast"/>
  </xsl:template>
  
  <!-- Whitespace cleanup -->
  
  <xsl:template match="text()"
                mode="ast-clean">
    <xsl:variable name="normalized" select="normalize-space(.)" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$normalized">
        <xsl:if test="preceding-sibling::node() and matches(., '^\s') and $normalized">
          <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:value-of select="$normalized"/>
        <xsl:if test="following-sibling::node() and matches(., '\s$') and $normalized">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xsl:if test="preceding-sibling::node() and following-sibling::node()">
          <xsl:text> </xsl:text>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="pandoc/text() |
                       div/text() |
                       bulletlist/text() |
                       orderedlist/text() |
                       definitionlist/text() |
                       dlentry/text() |
                       table/text() |
                       thead/text() |
                       tbody/text() |
                       tr/text()"
                mode="ast-clean" priority="10">
    <!--xsl:value-of select="normalize-space(.)"/-->
  </xsl:template>
  
  <xsl:template match="codeblock//text()"
                mode="ast-clean" priority="20">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="@* | node()"
                mode="ast-clean" priority="-10">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="ast-clean"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Flatten -->
  
  <xsl:function name="ast:is-container-block" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="$node/self::rawblock or
      $node/self::blockquote or
      (:$node/self::orderedlist or
      $node/self::bulletlist or:)
      $node/self::li or
      (:$node/self::definitionlist or $node/self::dt or:) $node/self::dd or
      (:$node/self::table or $node/self::thead or $node/self::tbody or $node/self::tr or $node/self::tablecell or:)
      $node/self::div or
      $node/self::null"/>
  </xsl:function>
  
  <xsl:function name="ast:is-block" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="$node/self::plain or
      $node/self::para or
      $node/self::codeblock or
      $node/self::rawblock or
      $node/self::blockquote or
      $node/self::orderedlist or
      $node/self::bulletlist or
      $node/self::definitionlist or $node/self::dlentry or $node/self::dt or $node/self::dd or
      $node/self::header or
      $node/self::horizontalrule or
      $node/self::table or $node/self::thead or $node/self::tbody or $node/self::tr or $node/self::tablecell or
      $node/self::div or
      $node/self::null"/>
  </xsl:function>
  
  <xsl:template match="@* | node()" mode="flatten" priority="-1000">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="flatten"/>
    </xsl:copy>
  </xsl:template>
  
  
  <!--xsl:template match="*[contains(@class, ' task/step ') or
                         contains(@class, ' task/substep ')]" mode="flatten" priority="100">
    <xsl:copy>
      <xsl:apply-templates select="@* | *" mode="flatten"/>
    </xsl:copy>
  </xsl:template-->
  
  <xsl:template match="para" mode="flatten" priority="100">
    <xsl:choose>
      <xsl:when test="empty(node())"/>
      <xsl:when test="count(*) eq 1 and
                      (*[ast:is-container-block(.)]) and 
                      empty(text()[normalize-space(.)])">
        <xsl:apply-templates mode="flatten"/>
      </xsl:when>
      <xsl:when test="descendant::*[ast:is-block(.)]">
        <xsl:variable name="current" select="." as="element()"/>
        <xsl:variable name="first" select="node()[1]" as="node()?"/>
        <xsl:for-each-group select="node()" group-adjacent="ast:is-block(.)">
          <xsl:choose>
            <xsl:when test="current-grouping-key()">
              <xsl:apply-templates select="current-group()" mode="flatten"/>
            </xsl:when>
            <xsl:when test="count(current-group()) eq 1 and current-group()/self::text() and not(normalize-space(current-group()))"/>
            <xsl:when test="parent::li and $first is current-group()[1]">
              <plain>
                <xsl:apply-templates select="current-group()" mode="flatten"/>
              </plain>
            </xsl:when>
            <xsl:otherwise>
              <para gen="1">
                <xsl:apply-templates select="$current/@* except $current/@id | current-group()" mode="flatten"/>
              </para>
            </xsl:otherwise>  
          </xsl:choose>
        </xsl:for-each-group>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@* | node()" mode="flatten"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- wrapper elements -->
  <xsl:template match="*[ast:is-container-block(.)]" mode="flatten" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="flatten"/>
      <xsl:variable name="first" select="node()[1]" as="node()?"/>
      <xsl:for-each-group select="node()" group-adjacent="ast:is-block(.)">
        <xsl:choose>
          <xsl:when test="current-grouping-key()">
            <xsl:apply-templates select="current-group()" mode="flatten"/>
          </xsl:when>
          <xsl:when test="count(current-group()) eq 1 and current-group()/self::text() and not(normalize-space(current-group()))"/>
          <xsl:when test="parent::li and $first is current-group()[1]">
            <plain>
              <xsl:apply-templates select="current-group()" mode="flatten"/>
            </plain>
          </xsl:when>
          <xsl:otherwise>
            <para>
              <xsl:apply-templates select="current-group()" mode="flatten"/>
            </para>
          </xsl:otherwise>  
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:copy>
  </xsl:template>

  <!-- YAML -->

  <xsl:template match="head" mode="ast">
    <xsl:text>---&#xA;</xsl:text>
    <xsl:apply-templates select="*" mode="#current"/>
    <xsl:text>---&#xA;&#xA;</xsl:text>
  </xsl:template>

  <xsl:template match="map" mode="ast">
    <xsl:for-each select="entry">
      <xsl:value-of select="@key"/>
      <xsl:text>: </xsl:text>
      <xsl:apply-templates mode="#current"/>
      <xsl:text>&#xA;</xsl:text>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="array" mode="ast">
    <xsl:text>[</xsl:text>
    <xsl:for-each select="entry">
      <xsl:if test="position() ne 1">, </xsl:if>
      <xsl:apply-templates mode="#current"/>
    </xsl:for-each>
    <xsl:text>]</xsl:text>
  </xsl:template>
  
</xsl:stylesheet>