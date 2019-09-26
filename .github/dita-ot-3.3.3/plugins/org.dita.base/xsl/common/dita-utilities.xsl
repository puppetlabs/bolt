<?xml version="1.0" encoding="utf-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<!-- Common utilities that can be used by DITA transforms -->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                exclude-result-prefixes="xs dita-ot">

  <xsl:include href="plugin:org.dita.base:xsl/common/functions.xsl"/>

  <xsl:param name="defaultLanguage" select="'en'" as="xs:string"/>

  <xsl:param name="DEFAULTLANG" select="if (/*/@xml:lang) then /*/@xml:lang else $defaultLanguage" as="xs:string"/>

  <xsl:param name="variableFiles.url" select="'plugin:org.dita.base:xsl/common/strings.xml'"/>
  
  <xsl:variable name="pixels-per-inch" select="number(96)"/>

  <xsl:key name="id" match="*[@id]" use="@id"/>

  <!-- Function to determine the current language, and return it in lower case -->
  <xsl:template name="getLowerCaseLang">
    <xsl:value-of select="dita-ot:get-current-language(.)"/>
  </xsl:template>
  
  <xsl:function name="dita-ot:capitalize">
    <xsl:param name="text" as="xs:string"/>
    <xsl:value-of select="concat(upper-case(substring($text, 1, 1)),
                                 lower-case(substring($text, 2)))"/>
  </xsl:function>

  <xsl:template match="*" mode="get-first-topic-lang">
    <xsl:sequence select="dita-ot:get-first-topic-language(.)"/>
  </xsl:template>

  <xsl:template match="*" mode="get-render-direction">
    <xsl:param name="lang">
      <xsl:apply-templates select="/*" mode="get-first-topic-lang"/>
    </xsl:param>
    <xsl:variable name="l" select="tokenize($lang, '-')[1]" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$l = 'ar'">rtl</xsl:when>
      <xsl:when test="$l = 'arc'">rtl</xsl:when>
      <xsl:when test="$l = 'bcc'">rtl</xsl:when>
      <xsl:when test="$l = 'bqi'">rtl</xsl:when>
      <xsl:when test="$l = 'ckb'">rtl</xsl:when>
      <xsl:when test="$l = 'dv'">rtl</xsl:when>
      <xsl:when test="$l = 'fa'">rtl</xsl:when>
      <xsl:when test="$l = 'glk'">rtl</xsl:when>
      <xsl:when test="$l = 'he'">rtl</xsl:when>
      <xsl:when test="$l = 'lrc'">rtl</xsl:when>
      <xsl:when test="$l = 'mzn'">rtl</xsl:when>
      <xsl:when test="$l = 'pnb'">rtl</xsl:when>
      <xsl:when test="$l = 'ps'">rtl</xsl:when>
      <xsl:when test="$l = 'sd'">rtl</xsl:when>
      <xsl:when test="$l = 'ug'">rtl</xsl:when>
      <xsl:when test="$l = 'ur'">rtl</xsl:when>
      <xsl:when test="$l = 'yi'">rtl</xsl:when>
      <xsl:otherwise>ltr</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:variable name="variableFiles" select="document($variableFiles.url)/langlist/lang" as="element(lang)*"/>
  
  <!-- Deprecated. Use getVariable template instead. -->
  <xsl:template name="getString">
    <xsl:param name="stringName"/>
    
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX066W'"/>
      <xsl:with-param name="msgparams">%1=getString</xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="string($stringName)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="getVariable">
    <xsl:param name="id" as="xs:string"/>
    <xsl:param name="params" as="node()*"/>
    <xsl:param name="ctx" as="node()" select="."/>
    <xsl:sequence select="dita-ot:get-variable($ctx, $id, $params)"/>
  </xsl:template>

  <xsl:template name="findString">
    <xsl:param name="id" as="xs:string"/>
    <xsl:param name="params" as="node()*"/>
    <xsl:param name="ancestorlang" as="xs:string*"/>
    <xsl:param name="defaultlang" as="xs:string*"/>
    <xsl:param name="originallang" as="xs:string*" select="$ancestorlang[1]"/>

    <xsl:variable name="l" select="($ancestorlang, $defaultlang)[1]" as="xs:string?"/>
    <xsl:choose>
      <xsl:when test="exists($l)">
        <xsl:variable name="variablefile" select="$variableFiles[lower-case(@xml:lang) = lower-case($l)]/@filename" as="xs:string*"/>
        <xsl:variable name="variable" as="element()*">
          <xsl:for-each select="$variablefile">
            <xsl:sequence select="document(., $variableFiles[1])/*/*[@name = $id or @id = $id]"/><!-- strings/str/@name opentopic-vars:vars/opentopic-vars:variable/@id -->
          </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="exists($variable)">
            <xsl:apply-templates select="$variable[last()]" mode="processVariableBody">
              <xsl:with-param name="params" select="$params"/>
            </xsl:apply-templates>
            <xsl:if test="empty($ancestorlang)">
              <xsl:call-template name="output-message">
                <xsl:with-param name="id" select="'DOTX001W'"/>
                <xsl:with-param name="msgparams">%1=<xsl:value-of select="$id"/>;%2=<xsl:value-of select="$originallang"/>;%3=<xsl:value-of select="$DEFAULTLANG"/></xsl:with-param>
              </xsl:call-template>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="findString">
              <xsl:with-param name="id" select="$id"/>
              <xsl:with-param name="params" select="$params"/>
              <xsl:with-param name="ancestorlang" select="$ancestorlang[position() gt 1]"/>
              <xsl:with-param name="defaultlang" select="if (exists($ancestorlang)) then $defaultlang else $defaultlang[position() gt 1]"/>
              <xsl:with-param name="originallang" select="$originallang"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="variablefile" select="$variableFiles[@xml:lang='']/@filename" as="xs:string*"/>
        <xsl:variable name="variable" as="element()*">
          <xsl:for-each select="$variablefile">
            <xsl:sequence select="document(., $variableFiles[1])/*/*[@name = $id or @id = $id]"/>
          </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="exists($variable)">
            <xsl:apply-templates select="$variable[last()]" mode="processVariableBody">
              <xsl:with-param name="params" select="$params"/>
            </xsl:apply-templates>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$id"/>
            <xsl:call-template name="output-message">
              <xsl:with-param name="id" select="'DOTX052W'"/>
              <xsl:with-param name="msgparams">%1=<xsl:value-of select="$id"/></xsl:with-param>
            </xsl:call-template>            
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Support legacy variable syntax -->
  <xsl:template match="str" mode="processVariableBody">
    <xsl:param name="params"/>
    <xsl:copy-of select="node()"/>
  </xsl:template>

  <xsl:template match="variable" mode="processVariableBody">
    <xsl:param name="params" as="node()*"/>
    
    <xsl:for-each select="node()">
      <xsl:choose>
        <xsl:when test="self::param">
          <xsl:variable name="param-name" select="@ref-name" as="xs:string"/>
          <xsl:copy-of select="$params/descendant-or-self::*[name() = $param-name]/node()"/>
        </xsl:when>
        <xsl:when test="self::variableref">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="@refid"/>
            <xsl:with-param name="params" select="$params"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:copy-of select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
    
  <xsl:template name="length-to-pixels">
    <xsl:param name="dimen"/>
    <!-- We handle units of cm, mm, in, pt, pc, px.  We also accept em,
      but just treat 1em=1pc.  An omitted unit is taken as px. -->
    
    <xsl:variable name="units" select="substring($dimen, string-length($dimen) - 1)"/>
    <xsl:variable name="numeric-value" select="number(substring($dimen, 1, string-length($dimen) - 2))"/>
    <xsl:choose>
      <xsl:when test="string(number($dimen)) != 'NaN'">
        <!-- Since $units is a number, the input was unitless, so we default
          the unit to pixels and just return the input value -->
        <xsl:value-of select="round(number($dimen))"/>
      </xsl:when>
      <xsl:when test="string($numeric-value) = 'NaN'">
        <!-- If the input isn't valid, just return 100% -->
        <xsl:value-of select="'100%'"/>
      </xsl:when>
      <xsl:when test="$units='cm'">
        <xsl:value-of select="round($numeric-value * $pixels-per-inch div 2.54)"/>
      </xsl:when>
      <xsl:when test="$units='mm'">
        <xsl:value-of select="round($numeric-value * $pixels-per-inch div 25.4)"/>
      </xsl:when>
      <xsl:when test="$units='in'">
        <xsl:value-of select="round($numeric-value * $pixels-per-inch)"/>
      </xsl:when>
      <xsl:when test="$units='pt'">
        <xsl:value-of select="round($numeric-value * $pixels-per-inch div 72)"/>
      </xsl:when>
      <xsl:when test="$units='pc'">
        <xsl:value-of select="round($numeric-value * $pixels-per-inch div 6)"/>
      </xsl:when>
      <xsl:when test="$units='px'">
        <xsl:value-of select="round($numeric-value)"/>
      </xsl:when>
      <xsl:when test="$units='em'">
        <xsl:value-of select="round($numeric-value * $pixels-per-inch div 6)"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- If the input isn't valid, just return 100% -->
        <xsl:value-of select="'100%'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="replace">
    <xsl:param name="text" as="xs:string?"/>
    <xsl:param name="from" as="xs:string"/>
    <xsl:param name="to"/>
    <xsl:choose>
      <xsl:when test="contains($text, $from)">
        <xsl:sequence select="substring-before($text, $from)[string-length(.) gt 0]"/>
        <xsl:copy-of select="$to"/>
        <xsl:call-template name="replace">
          <xsl:with-param name="text" select="substring-after($text, $from)[string-length(.) gt 0]"/>
          <xsl:with-param name="from" select="$from"/>
          <xsl:with-param name="to" select="$to"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- replace all the blank in file name or directory with %20 -->
  <xsl:template name="replace-blank">
    <xsl:param name="file-origin"></xsl:param>
    <xsl:choose>
      <xsl:when test="contains($file-origin,' ')">
        <xsl:call-template name="replace-blank">
          <xsl:with-param name="file-origin">
            <xsl:value-of select="substring-before($file-origin,' ')"/>%20<xsl:value-of select="substring-after($file-origin,' ')"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$file-origin"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
<!-- Return the portion of an HREF value up to the file's extension. This assumes
     that the file has an extension, and that the topic and/or element ID does not
     contain a period. Written to allow references such as com.example.dita.files/file.dita#topic -->
<!-- Deprecated: use replace-extension instead -->
<xsl:template match="*" mode="parseHrefUptoExtension">
  <xsl:param name="href" select="@href"/>
  
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX069W'"/>
    <xsl:with-param name="msgparams">%1=parseHrefUptoExtension</xsl:with-param>
  </xsl:call-template>  
  <xsl:variable name="uptoDot" select="substring-before($href,'.')" as="xs:string"/>
  <xsl:variable name="afterDot" select="substring-after($href,'.')" as="xs:string"/>
  <xsl:value-of select="$uptoDot"/>
  <xsl:choose>
    <!-- No more periods, so this is at the extension -->
    <xsl:when test="not(contains($afterDot,'.'))"/>
    <!-- Multiple slashes; at least one must be a directory, so it's before the extension -->
    <xsl:when test="contains(substring-after($afterDot,'/'),'/')">
      <xsl:text>.</xsl:text>
      <xsl:value-of select="substring-before($afterDot,'/')"/>
      <xsl:text>/</xsl:text>
      <xsl:apply-templates select="." mode="parseHrefUptoExtension"><xsl:with-param name="href" select="substring-after($afterDot,'/')"/></xsl:apply-templates>
    </xsl:when>
    <!-- Multiple periods, no slashes, no topic or element ID, so the file name contains more periods -->
    <xsl:when test="not(contains($afterDot,'#'))">
      <xsl:text>.</xsl:text>
      <xsl:apply-templates select="." mode="parseHrefUptoExtension"><xsl:with-param name="href" select="$afterDot"/></xsl:apply-templates>
    </xsl:when>
    <!-- Multiple periods, no slashes, with #. Move to next period. Needs additional work to support
         IDs containing periods. -->
    <xsl:otherwise>
      <xsl:text>.</xsl:text>
      <xsl:apply-templates select="." mode="parseHrefUptoExtension"><xsl:with-param name="href" select="$afterDot"/></xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
  
  <!-- Get filename base -->
  <xsl:template name="getFileName">
    <xsl:param name="filename"/>
    <xsl:param name="extension"/>
    <xsl:choose>
      <xsl:when test="contains($filename, $extension)">
        <xsl:call-template name="substring-before-last">
          <xsl:with-param name="text" select="$filename"/>
          <xsl:with-param name="delim" select="$extension"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$filename"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Replace file extension in a URI -->
  <xsl:template name="replace-extension" as="xs:string">
    <xsl:param name="filename" as="xs:string"/>
    <xsl:param name="extension" as="xs:string"/>
    <xsl:param name="ignore-fragment" select="false()"/>
    <xsl:variable name="f" as="xs:string">
      <xsl:value-of>
       <xsl:call-template name="substring-before-last">
         <xsl:with-param name="text">
           <xsl:choose>
             <xsl:when test="contains($filename, '#')">
               <xsl:value-of select="substring-before($filename, '#')"/>
             </xsl:when>
             <xsl:otherwise>
               <xsl:value-of select="$filename"/>
             </xsl:otherwise>
           </xsl:choose>
         </xsl:with-param>
         <xsl:with-param name="delim" select="'.'"/>
       </xsl:call-template>
      </xsl:value-of>
    </xsl:variable>
    <xsl:value-of>
      <xsl:if test="string($f)">
        <xsl:value-of select="concat($f, $extension)"/>  
      </xsl:if>
      <xsl:if test="not($ignore-fragment) and contains($filename, '#')">
        <xsl:value-of select="concat('#', substring-after($filename, '#'))"/>
      </xsl:if>
    </xsl:value-of>
  </xsl:template>
  
  <xsl:function name="dita-ot:substring-before-last" as="xs:string?">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="delim" as="xs:string"/>
    
    <xsl:call-template name="substring-before-last">
      <xsl:with-param name="text" select="$text"/>
      <xsl:with-param name="delim" select="$delim" />
    </xsl:call-template>
  </xsl:function>
  
  <xsl:template name="substring-before-last" as="xs:string?">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="delim" as="xs:string"/>
    <xsl:param name="acc" as="xs:string?"/>
    
    <xsl:choose>
      <xsl:when test="string($text) and string($delim)">
        <xsl:variable name="tail" select="substring-after($text, $delim)" />
        <xsl:choose>
          <xsl:when test="contains($tail, $delim)">
            <xsl:call-template name="substring-before-last">
              <xsl:with-param name="text" select="$tail" />
              <xsl:with-param name="delim" select="$delim" />
              <xsl:with-param name="acc" select="concat($acc, substring-before($text, $delim), $delim)"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat($acc, substring-before($text, $delim))"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$acc"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="processing-instruction('workdir-uri')" mode="get-work-dir">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="processing-instruction('path2project-uri')" mode="get-path2project">
    <xsl:choose>
      <!-- Backwards compatibility with path2project that is empty when current directory is the root directory -->
      <xsl:when test=". = './'"/>
      <xsl:otherwise>
        <xsl:value-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="processing-instruction('path2project')" mode="get-path2project">
    <xsl:call-template name="get-path2project">
      <xsl:with-param name="s" select="."/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="get-path2project">
    <!-- Deal with being handed a Windows backslashed path by accident. -->
    <!-- This code only changes \ to / and doesn't handle the many other situations
         where a URI differs from a file path.  Hopefully they don't occur in path2proj anyway. -->
    <xsl:param name="s"/>
    <xsl:choose>
      <xsl:when test="contains($s, '\')">
        <xsl:value-of select="substring-before($s, '\')"/>
        <xsl:text>/</xsl:text>
        <xsl:call-template name="get-path2project">
          <xsl:with-param name="s" select="substring-after($s, '\')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$s"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:function name="dita-ot:get-closest-topic" as="element()">
    <xsl:param name="n" as="node()"/>

    <xsl:sequence
      select="$n/ancestor-or-self::*[contains(@class, ' topic/topic ')][1]"/>
  </xsl:function>

  <xsl:include href="plugin:org.dita.base:xsl/common/uri-utils.xsl"/>

</xsl:stylesheet>

