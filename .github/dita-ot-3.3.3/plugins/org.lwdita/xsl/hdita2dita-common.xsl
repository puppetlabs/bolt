<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ditaarch="http://dita.oasis-open.org/architecture/2005/"
                xmlns:x="https://github.com/jelovirt/dita-ot-markdown"
                exclude-result-prefixes="xs x"
                xpath-default-namespace="http://www.w3.org/1999/xhtml"
                version="2.0">

  <!-- Topic -->

  <xsl:template match="html">
    <xsl:choose>
      <xsl:when test="count(body/article) gt 1">
        <dita>
          <xsl:attribute name="ditaarch:DITAArchVersion">1.3</xsl:attribute>
          <xsl:apply-templates select="@* | node()"/>
        </dita>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="body"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="head"/>

  <xsl:template match="body">
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template match="article">
    <xsl:variable name="name" select="(:if (@data-hd-class) then @data-hd-class else :)'topic'"/>
    <xsl:element name="{$name}">
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="." mode="topic"/>
      <xsl:attribute name="ditaarch:DITAArchVersion">1.3</xsl:attribute>
      <xsl:apply-templates select="ancestor::*/@xml:lang"/>
      <xsl:apply-templates select="@*"/>
      <xsl:variable name="h" select="(h1, h2, h3, h4, h5, h6)[1]" as="element()?"/>
      <xsl:choose>
        <xsl:when test="@id">
          <xsl:apply-templates select="@id"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="x:get-id(.)"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="$h"/>
      <xsl:variable name="contents" select="* except ($h, article)" as="element()*"/>
      <xsl:variable name="shortdesc" select="$contents[1]/self::p" as="element()?"/>
      <xsl:if test="$shortdesc">
        <shortdesc class="- topic/shortdesc ">
          <xsl:apply-templates select="$shortdesc/node()"/>
        </shortdesc>
      </xsl:if>
      <!--xsl:if test="$contents except $shortdesc"-->
        <body class="- topic/body ">
          <xsl:apply-templates select="$contents except $shortdesc"/>
        </body>
      <!--/xsl:if-->
      <xsl:apply-templates select="article"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:function name="x:get-id" as="attribute()?">
    <xsl:param name="topic" as="element()"/>
    <xsl:variable name="title" select="($topic/h1 | $topic/h2 | $topic/h3 | $topic/h4 | $topic/h5 | $topic/h6)[1]" as="element()?"/>
    <xsl:if test="$title">
      <xsl:attribute name="id" select="translate(normalize-space(lower-case($title)), ' .', '-')"/>
    </xsl:if>
  </xsl:function>

  <xsl:template match="article" mode="class">
    <xsl:attribute name="class">
      <xsl:text>- topic/topic </xsl:text>
      <!--
      <xsl:if test="@data-hd-class">
        <xsl:value-of select="concat(@data-hd-class, '/', @data-hd-class, ' ')"/>
      </xsl:if>
      -->
    </xsl:attribute>
  </xsl:template>
  <!--
  <xsl:template match="article[@data-hd-class = 'concept']" mode="class">
    <xsl:attribute name="class">- topic/topic concept/concept </xsl:attribute>
  </xsl:template>
  <xsl:template match="article[@data-hd-class = 'task']" mode="class">
    <xsl:attribute name="class">- topic/topic task/task </xsl:attribute>
  </xsl:template>
  <xsl:template match="article[@data-hd-class = 'reference']" mode="class">
    <xsl:attribute name="class">- topic/topic reference/reference </xsl:attribute>
  </xsl:template>
  -->

  <xsl:template match="article" mode="topic">
    <xsl:attribute name="domains">(topic abbrev-d) a(props deliveryTarget) (topic equation-d) (topic hazard-d) (topic hi-d) (topic indexing-d) (topic markup-d) (topic mathml-d) (topic pr-d) (topic relmgmt-d) (topic sw-d) (topic svg-d) (topic ui-d) (topic ut-d) (topic markup-d xml-d)</xsl:attribute>
  </xsl:template>
  <!--
  <xsl:template match="article[@data-hd-class = 'concept']" mode="topic">
    <xsl:attribute name="domains">(topic abbrev-d) a(props deliveryTarget) (topic equation-d) (topic hazard-d) (topic hi-d) (topic indexing-d) (topic markup-d) (topic mathml-d) (topic pr-d) (topic relmgmt-d) (topic sw-d) (topic svg-d) (topic ui-d) (topic ut-d) (topic markup-d xml-d)</xsl:attribute>
  </xsl:template>
  <xsl:template match="article[@data-hd-class = 'task']" mode="topic">
    <xsl:attribute name="domains">(topic concept) (topic abbrev-d) a(props deliveryTarget) (topic equation-d) (topic hazard-d) (topic hi-d) (topic indexing-d) (topic markup-d) (topic mathml-d) (topic pr-d) (topic relmgmt-d) (topic sw-d) (topic svg-d) (topic ui-d) (topic ut-d) (topic markup-d xml-d)</xsl:attribute>
  </xsl:template>
  <xsl:template match="article[@data-hd-class = 'reference']" mode="topic">
    <xsl:attribute name="domains">(topic reference) (topic abbrev-d) a(props deliveryTarget) (topic equation-d) (topic hazard-d) (topic hi-d) (topic indexing-d) (topic markup-d) (topic mathml-d) (topic pr-d) (topic relmgmt-d) (topic sw-d) (topic svg-d) (topic ui-d) (topic ut-d) (topic markup-d xml-d)</xsl:attribute>
  </xsl:template>
  -->
  
  <xsl:template match="section">
    <xsl:variable name="name" select="(:if (@data-hd-class = 'topic/example') then 'example' else :)'section'"/>
    <xsl:element name="{$name}">
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@*"/>
      <xsl:if test="empty(@id)">
        <xsl:sequence select="x:get-id(.)"/>
      </xsl:if>
      <xsl:apply-templates select="*"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="section" mode="class">
    <xsl:attribute name="class">
      <!--
      <xsl:choose>
        <xsl:when test="@data-hd-class = 'topic/example'">
          <xsl:text>- topic/example </xsl:text>
        </xsl:when>
        <xsl:when test="contains(@data-hd-class, '/')">
          <xsl:text>- topic/section </xsl:text>
          <xsl:value-of select="concat(@data-hd-class, '/', @data-hd-class)"/>
          <xsl:text> </xsl:text>
        </xsl:when>
        <xsl:otherwise>
        -->
          <xsl:text>- topic/section </xsl:text>
      <!--
        </xsl:otherwise>
      </xsl:choose>
      -->
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6">
    <title>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* except @id | node()"/>
    </title>
  </xsl:template>
  <xsl:template match="h1 | h2 | h3 | h4 | h5 | h6" mode="class">
    <xsl:attribute name="class">- topic/title </xsl:attribute>
  </xsl:template>

  <xsl:template match="dl">
    <xsl:element name="{name()}">
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each-group select="*" group-starting-with="dt[empty(preceding-sibling::*[1]/self::dt)]">
        <dlentry class="- topic/dlentry ">
          <xsl:apply-templates select="current-group()"/>
        </dlentry>
      </xsl:for-each-group>
    </xsl:element>
  </xsl:template>
  <xsl:template match="dd">
    <dd>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@*"/>
      <xsl:variable name="first-block" select="(*[x:is-html-block(.)])[1]" as="element()?"/>
      <xsl:choose>
        <xsl:when test="empty($first-block)">
          <p class="- topic/p ">
            <xsl:apply-templates select="node()"/>
          </p>
        </xsl:when>
        <xsl:when test="exists($first-block) and $first-block/preceding-sibling::node()[not(self::text()[not(normalize-space(.))])]">
          <p class="- topic/p ">
            <xsl:apply-templates select="$first-block/preceding-sibling::node()"/>
          </p>
          <xsl:apply-templates select="$first-block | $first-block/following-sibling::node()"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="node()"/>    
        </xsl:otherwise>
      </xsl:choose>
    </dd>
  </xsl:template>
  
  <xsl:function name="x:is-html-block" as="xs:boolean">
    <xsl:param name="node" as="node()?"/>
    <xsl:sequence select="exists(
      $node/self::address |
      $node/self::article |
      $node/self::aside |
      $node/self::blockquote |
      $node/self::canvas |
      $node/self::dd |
      $node/self::div |
      $node/self::dl |
      $node/self::dt |
      $node/self::fieldset |
      $node/self::figcaption |
      $node/self::figure |
      $node/self::figcaption |
      $node/self::footer |
      $node/self::form |
      $node/self::h1 |
      $node/self::h2 |
      $node/self::h3 |
      $node/self::h4 |
      $node/self::h5 |
      $node/self::h6 |
      $node/self::header |
      $node/self::hgroup |
      $node/self::hr |
      $node/self::li |
      $node/self::main |
      $node/self::nav |
      $node/self::noscript |
      $node/self::ol |
      $node/self::output |
      $node/self::p |
      $node/self::pre |
      $node/self::section |
      $node/self::table |
      $node/self::tfoot |
      $node/self::ul |
      $node/self::video
      )"/>
  </xsl:function>

  <xsl:template match="@xml:lang">
    <xsl:attribute name="lang" select="."/>
  </xsl:template>

  <xsl:template match="figure">
    <fig>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="figcaption"/>
      <xsl:apply-templates select="node() except figcaption"/>
    </fig>
  </xsl:template>
  <xsl:template match="figure" mode="class">
    <xsl:attribute name="class">- topic/fig </xsl:attribute>
  </xsl:template>

  <xsl:template match="pre">  
    <pre>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:attribute name="xml:space">preserve</xsl:attribute>
      <xsl:apply-templates select="@* | node()"/>
    </pre>
  </xsl:template>
  <xsl:template match="pre" mode="class">
    <xsl:attribute name="class">- topic/pre </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="pre[code]">
    <codeblock>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:attribute name="xml:space">preserve</xsl:attribute>
      <xsl:apply-templates select="@* | code/node()"/>
    </codeblock>
  </xsl:template>
  <xsl:template match="pre[code]" mode="class">
    <xsl:attribute name="class">+ topic/pre pr-d/codeblock </xsl:attribute>
  </xsl:template>

  <xsl:template match="img">
    <image>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* except @alt"/>
      <xsl:apply-templates select="." mode="image-placement"/>
      <xsl:if test="@alt">
        <alt class="- topic/alt ">
          <xsl:value-of select="@alt"/>
        </alt>
      </xsl:if>
    </image>
  </xsl:template>
  <xsl:template match="article/img | section/img" mode="image-placement">
    <xsl:attribute name="placement">break</xsl:attribute>
  </xsl:template>
  <xsl:template match="node()" mode="image-placement" priority="-10"/>
  <xsl:template match="img" mode="class">
    <xsl:attribute name="class">- topic/image </xsl:attribute>
  </xsl:template>
  <xsl:template match="img/@src">
    <xsl:attribute name="href" select="."/>
  </xsl:template>

  <xsl:template match="table">
    <xsl:variable name="cols" as="xs:integer" select="max(descendant::tr/count(*))"/>
    <table>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | caption"/>
      <tgroup class="- topic/tgroup "  cols="{$cols}">
        <xsl:for-each select="1 to $cols">
          <colspec class="- topic/colspec " colname="col{.}"/>
        </xsl:for-each>
        <xsl:choose>
          <xsl:when test="tr[1][th and empty(td)]">
            <thead class="- topic/thead ">
              <xsl:apply-templates select="tr[1]"/>
            </thead>
            <tbody class="- topic/tbody ">
              <xsl:apply-templates select="tr[position() ne 1]"/>
            </tbody>
          </xsl:when>
          <xsl:when test="tr">
            <tbody class="- topic/tbody ">
              <xsl:apply-templates select="tr"/>
            </tbody>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="thead | tbody"/>
          </xsl:otherwise>
        </xsl:choose>
      </tgroup>
    </table>
  </xsl:template>
  <xsl:template match="table/caption | figcaption">
    <title>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </title>
  </xsl:template>
  <xsl:template match="table/caption | figcaption" mode="class">
    <xsl:attribute name="class">- topic/title </xsl:attribute>
  </xsl:template>
  <xsl:template match="tr">
    <row>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </row>
  </xsl:template>
  <xsl:template match="tr" mode="class">
    <xsl:attribute name="class">- topic/row </xsl:attribute>
  </xsl:template>
  <xsl:template match="td | th">
    <entry>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </entry>
  </xsl:template>
  <xsl:template match="td | th" mode="class">
    <xsl:attribute name="class">- topic/entry </xsl:attribute>
  </xsl:template>
  <xsl:template match="@rowspan">
    <xsl:attribute name="morerows" select="xs:integer(.) - 1"/>
  </xsl:template>

  <!--
  <xsl:template match="*[@data-hd-class = 'topic/example']" mode="class">
    <xsl:attribute name="class">- topic/example </xsl:attribute>
  </xsl:template>
  -->

  <xsl:template match="br">
    <xsl:processing-instruction name="linebreak"/>
  </xsl:template>
  <xsl:template match="b | strong" mode="class">
    <xsl:attribute name="class">+ topic/ph hi-d/b </xsl:attribute>
  </xsl:template>
  <xsl:template match="i | em" mode="class">
    <xsl:attribute name="class">+ topic/ph hi-d/i </xsl:attribute>
  </xsl:template>
  <xsl:template match="u" mode="class">
    <xsl:attribute name="class">+ topic/ph hi-d/u </xsl:attribute>
  </xsl:template>
  <xsl:template match="span">
    <ph>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </ph>
  </xsl:template>
  <xsl:template match="span" mode="class">
    <xsl:attribute name="class">- topic/ph </xsl:attribute>
  </xsl:template>
  <xsl:template match="@data-keyref">
    <xsl:attribute name="keyref" select="."/>
  </xsl:template>
  <xsl:template match="strong">
    <b>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </b>
  </xsl:template>
  <xsl:template match="em">
    <i>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </i>
  </xsl:template>
  <xsl:template match="sup">
    <sup>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </sup>
  </xsl:template>
  <xsl:template match="sup" mode="class">
    <xsl:attribute name="class">+ topic/ph hi-d/sup </xsl:attribute>
  </xsl:template>
  <xsl:template match="sub">
    <sub>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </sub>
  </xsl:template>
  <xsl:template match="sub" mode="class">
    <xsl:attribute name="class">+ topic/ph hi-d/sub </xsl:attribute>
  </xsl:template>
  <xsl:template match="a">
    <xsl:variable name="href" select="lower-case(if (contains(@href, '#')) then substring-before(@href, '#') else @href)"/>
    <xref>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:if test="@data-keyref">
        <xsl:attribute name="keyref" select="@data-keyref"/>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="starts-with(@href, 'mailto')">
          <xsl:attribute name="format">email</xsl:attribute>
          <xsl:attribute name="scope">external</xsl:attribute>
        </xsl:when>
        <xsl:when test="@type">
          <xsl:attribute name="format" select="@type"/>
        </xsl:when>
        <xsl:when test="ends-with($href, '.md')">
          <xsl:attribute name="format">markdown</xsl:attribute>
        </xsl:when>
        <xsl:when test="ends-with($href, '.dita') or ends-with($href, '.xml')"/>
        <xsl:when test="@href">
          <xsl:attribute name="format">
            <xsl:variable name="path" select="if (contains($href, '://'))
                                              then tokenize(substring-after($href, '://'), '/')[position() gt 1]
                                              else tokenize($href, '/')"/>
            <xsl:variable name="file" select="$path[position() eq last()]"/>
            <xsl:value-of select="if (matches($file, '^.+\.(\w+?)$'))
                                  then replace($file, '^.+\.(\w+?)$', '$1')
                                  else 'html'"/>
          </xsl:attribute>
        </xsl:when>
      </xsl:choose>
      <xsl:if test="matches(@href, '^https?://', 'i')">
        <xsl:attribute name="scope">external</xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node()"/>
    </xref>
  </xsl:template>
  <xsl:template match="a" mode="class">
    <xsl:attribute name="class">- topic/xref </xsl:attribute>
  </xsl:template>
  <xsl:template match="a/@target"/>
  <xsl:template match="del">
    <ph>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:attribute name="status">deleted</xsl:attribute>
      <xsl:apply-templates select="@* | node()"/>
    </ph>
  </xsl:template>
  <xsl:template match="del" mode="class">
    <xsl:attribute name="class">- topic/ph </xsl:attribute>
  </xsl:template>
  <xsl:template match="code">
    <codeph>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </codeph>
  </xsl:template>
  <xsl:template match="code" mode="class">
    <xsl:attribute name="class">+ topic/ph pr-d/codeph </xsl:attribute>
  </xsl:template>

  <!-- HDITA -->

  <xsl:template match="audio" mode="class">
    <xsl:attribute name="class">+ topic/object h5m-d/audio </xsl:attribute>
  </xsl:template>
  <xsl:template match="video" mode="class">
    <xsl:attribute name="class">+ topic/object h5m-d/video </xsl:attribute>
  </xsl:template>
  <xsl:template match="fallback" mode="class">
    <xsl:attribute name="class">+ topic/desc h5m-d/fallback </xsl:attribute>
  </xsl:template>
  <xsl:template match="controls" mode="class">
    <xsl:attribute name="class">+ topic/param h5m-d/controls </xsl:attribute>
    <xsl:attribute name="name" select="local-name()"/>
  </xsl:template>
  <xsl:template match="poster" mode="class">
    <xsl:attribute name="class">+ topic/param h5m-d/poster </xsl:attribute>
    <xsl:attribute name="name" select="local-name()"/>
  </xsl:template>
  <xsl:template match="source" mode="class">
    <xsl:attribute name="class">+ topic/param h5m-d/source </xsl:attribute>
    <xsl:attribute name="name" select="local-name()"/>
  </xsl:template>
  <xsl:template match="track" mode="class">
    <xsl:attribute name="class">+ topic/param h5m-d/track </xsl:attribute>
    <xsl:attribute name="name" select="local-name()"/>
  </xsl:template>

  <!-- Map -->

  <xsl:template match="nav">
    <map>
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="." mode="topic"/>
      <xsl:attribute name="ditaarch:DITAArchVersion">1.3</xsl:attribute>
      <xsl:apply-templates select="ancestor::*/@xml:lang"/>
      <xsl:apply-templates select="@* | node()"/>
    </map>
  </xsl:template>
  <xsl:template match="nav" mode="class">
    <xsl:attribute name="class">- map/map </xsl:attribute>
  </xsl:template>

  <xsl:template match="nav/h1">
    <topicmeta class="- map/topicmeta ">
      <navtitle class="- map/navtitle ">
        <xsl:apply-templates select="@* | node()"/>
      </navtitle>
    </topicmeta>
  </xsl:template>

  <xsl:template match="nav//ul | nav//ol">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="nav//li">
    <topicref class="- map/topicref ">
      <topicmeta class="- map/topicmeta ">
        <navtitle class="- map/navtitle ">
          <xsl:apply-templates select="node() except (ol | ul)"/>
        </navtitle>
      </topicmeta>
      <xsl:apply-templates select="ol | ul"/>
    </topicref>
  </xsl:template>

  <!-- Common -->

  <xsl:template match="@class">
    <xsl:attribute name="outputclass" select="."/>
  </xsl:template>

  <!--
  <xsl:template match="*[@data-hd-class]" mode="class" priority="-5">
    <xsl:attribute name="class">
      <xsl:text>- </xsl:text>
      <xsl:value-of select="@data-hd-class"/>
      <xsl:text> </xsl:text>
    </xsl:attribute>
  </xsl:template>
  -->

  <xsl:template match="*" mode="class" priority="-10">
    <xsl:attribute name="class">
      <xsl:text>- topic/</xsl:text>
      <xsl:value-of select="local-name()"/>
      <xsl:text> </xsl:text>
    </xsl:attribute>
  </xsl:template>

  <xsl:template match="@* | node()" mode="class" priority="-15"/>

  <xsl:template match="*" priority="-10">
    <xsl:element name="{name()}">
      <xsl:apply-templates select="." mode="class"/>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="@* | node()" priority="-15">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@data-hd-class" priority="10"/>

  <xsl:template match="@data-conref" priority="10">
    <xsl:attribute name="conref" select="."/>
  </xsl:template>

  <xsl:template match="@data-conkeyref" priority="10">
    <xsl:attribute name="conkeyref" select="."/>
  </xsl:template>

</xsl:stylesheet>
