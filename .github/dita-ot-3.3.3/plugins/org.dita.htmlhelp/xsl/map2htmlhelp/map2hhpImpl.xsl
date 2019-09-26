<?xml version="1.0"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<!--
     Conversion from DITA map to HTML Help project.
     Input = one DITA map file
     Output = one HHP project file for use with the HTML Help compiler.

     Options:
        /OUTEXT  = XHTML output extension (default is '.html')
        /WORKDIR = The working directory that contains the document being transformed.
                   Needed as a directory prefix for the @href "document()" function calls.
                   Default is './'
        /HHCNAME = The name of the contents file associated with this help project
        /INCLUDEFILE = adds a #include for extra files in FILES section.
        /HELPALIAS = adds the ALIAS header & the #include
        /HELPMAP = adds the MAP header & the #include


-->


<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">

<!-- Include error message template -->
<xsl:include href="plugin:org.dita.base:xsl/common/output-message.xsl"/>

<!-- Set the prefix for error message numbers -->
<!-- Deprecated since 2.3 -->
<xsl:variable name="msgprefix">DOTX</xsl:variable>

<!-- *************************** Command line parameters *********************** -->
<xsl:param name="OUTEXT" select="'.html'"/>
<xsl:param name="WORKDIR" select="'./'"/>
<xsl:param name="HHCNAME" select="'help'"/>
<xsl:param name="USEINDEX" select="'yes'"/>  <!-- to turn on, use 'yes' -->
<xsl:param name="INCLUDEFILE" />
<xsl:param name="HELPALIAS" />
<xsl:param name="HELPMAP" />


<!-- Is there a way to prevent re-issuing the same filename, using keys? Doubt it... -->
<!-- <xsl:key name="amap" match="topicref" use="@href"/>
<xsl:key name="manymaps" match="map/document($WORKDIR@file)//topicref" use="@href"/> -->

<!-- *********************************************************************************
     Template to set up the HHP file. It should only be called once; it sets
     standard HHP options. The complex sections set the default topic that shows
     when you open the file, and the title of the HTML Help file. The default topic
     is the first topic used for navigation in the first processed map; the title is
     the title of the first map. If the first (or only) map does not have a title, none
     is used. NOTE - only non-external references to DITA or HTM/HTML files are
     considered valid for inclusion in the project, so only those will be evaluated to
     find the default topic.
     ********************************************************************************* -->
<!-- Language is that of map, else first topic with non-empty topicref, else English. --> 

<xsl:template name="setup-options">
<xsl:param name="target-language">
  <xsl:choose>
    <xsl:when test="/*[contains(@class, ' map/map ')]/@xml:lang">
      <xsl:value-of select="lower-case(/*[contains(@class, ' map/map ')]/@xml:lang)"/>
    </xsl:when>
    <xsl:when test="document((//*[contains(@class, ' map/topicref ')][@href and @href != '' and not(contains(@href,'://'))][not(@format) or @format='dita'][not(@scope) or @scope='local'])[1]/@href, /)//*[contains(@class, ' topic/topic ')][1]/@xml:lang">
      <xsl:value-of select="lower-case(document((//*[contains(@class, ' map/topicref ')][@href and @href != ''and not(contains(@href,'://'))][not(@format) or @format='dita'][not(@scope) or @scope='local'])[1]/@href, /)//*[contains(@class, ' topic/topic ')][1]/@xml:lang)"/>
    </xsl:when>
    <xsl:otherwise>en-us</xsl:otherwise>
  </xsl:choose>
</xsl:param>

<xsl:text>[OPTIONS]
Compiled file=</xsl:text><xsl:value-of select="substring-before($HHCNAME,'.hhc')"/><xsl:text>.chm
</xsl:text>
<xsl:if test="/*[contains(@class, ' map/map ')]">   <!-- Only reference HHC if there is valid navigation -->
  <xsl:text>Contents file=</xsl:text><xsl:value-of select="$HHCNAME"/><xsl:text>
</xsl:text>
</xsl:if>
<xsl:text>Default Window=default
Full-text search=Yes
Display compile progress=No
</xsl:text>
<xsl:if test="$USEINDEX='yes'">
<xsl:text>Index file=</xsl:text><xsl:value-of select="substring-before($HHCNAME,'.hhc')"/><xsl:text>.hhk
Binary Index=No
</xsl:text>
</xsl:if>
<xsl:text>Language=</xsl:text>
<xsl:choose>
  <xsl:when test="$target-language = 'ar' or starts-with($target-language, 'ar-')"><xsl:text>0x0c01 Arabic (EGYPT)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'be' or starts-with($target-language, 'be-')"><xsl:text>0x0423 Byelorussian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'bg' or starts-with($target-language, 'bg-')"><xsl:text>0x0402 Bulgarian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'ca' or starts-with($target-language, 'ca-')"><xsl:text>0x0403 Catalan</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'cs' or starts-with($target-language, 'cs-')"><xsl:text>0x0405 Czech</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'da' or starts-with($target-language, 'da-')"><xsl:text>0x0406 Danish</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'de-ch'"><xsl:text>0x0807 German (SWITZERLAND)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'de' or starts-with($target-language, 'de-')"><xsl:text>0x0407 German (GERMANY)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'el' or starts-with($target-language, 'el-')"><xsl:text>0x0408 Greek</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'en-gb'"><xsl:text>0x0809 English (UNITED KINGDOM)</xsl:text></xsl:when>
  <!-- en-uk seems to be a common misspelling of en-gb. -->
  <xsl:when test="$target-language = 'en-uk'"><xsl:text>0x0809 English (UNITED KINGDOM)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'en-us'"><xsl:text>0x0409 English (United States)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'en' or starts-with($target-language, 'en-')"><xsl:text>0x0409 English (United States)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'es' or starts-with($target-language, 'es-')"><xsl:text>0x040a Spanish (Spain)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'et' or starts-with($target-language, 'et-')"><xsl:text>0x0425 Estonian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'fi' or starts-with($target-language, 'fi-')"><xsl:text>0x040b Finnish</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'fr-be'"><xsl:text>0x080c French (BELGIUM)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'fr-ca'"><xsl:text>0x0c0c French (CANADA)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'fr-ch'"><xsl:text>0x100c French (SWITZERLAND)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'fr' or starts-with($target-language, 'fr-')"><xsl:text>0x040c French (FRANCE)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'he' or starts-with($target-language, 'he-')"><xsl:text>0x040d Hebrew</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'hr' or starts-with($target-language, 'hr-')"><xsl:text>0x041a Croatian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'hu' or starts-with($target-language, 'hu-')"><xsl:text>0x040e Hungarian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'is' or starts-with($target-language, 'is-')"><xsl:text>0x040f Icelandic</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'it-ch'"><xsl:text>0x0810 Italian (SWITZERLAND)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'it' or starts-with($target-language, 'it-')"><xsl:text>0x0410 Italian (ITALY)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'ja' or starts-with($target-language, 'ja-')"><xsl:text>0x0411 Japanese</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'ko' or starts-with($target-language, 'ko-')"><xsl:text>0x0412 Korean</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'lt' or starts-with($target-language, 'lt-')"><xsl:text>0x0427 Lithuanian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'lv' or starts-with($target-language, 'lv-')"><xsl:text>0x0426 Latvian (Lettish)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'mk' or starts-with($target-language, 'mk-')"><xsl:text>0x042f Macedonian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'nl-be'"><xsl:text>0x0813 Dutch (Belgium)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'nl' or starts-with($target-language, 'nl-')"><xsl:text>0x0413 Dutch (Netherlands)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'no' or starts-with($target-language, 'no-')"><xsl:text>0x0414 Norwegian (Bokmal)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'pl' or starts-with($target-language, 'pl-')"><xsl:text>0x0415 Polish</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'pt-br'"><xsl:text>0x0416 Portuguese (BRAZIL)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'pt-pt'"><xsl:text>0x0816 Portuguese (PORTUGAL)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'pt' or starts-with($target-language, 'pt-')"><xsl:text>0x0416 Portuguese (BRAZIL)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'ro' or starts-with($target-language, 'ro-')"><xsl:text>0x0418 Romanian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'ru' or starts-with($target-language, 'ru-')"><xsl:text>0x0419 Russian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'sk' or starts-with($target-language, 'sk-')"><xsl:text>0x041b Slovak</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'sl' or starts-with($target-language, 'sl-')"><xsl:text>0x0424 Slovenian</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'sr-cyrl'"><xsl:text>0x0c1a Serbian (Cyrillic)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'sr-latn'"><xsl:text>0x081a Serbian (Latin)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'sr' or starts-with($target-language, 'sr-')"><xsl:text>0x0c1a Serbian (Cyrillic)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'sv' or starts-with($target-language, 'sv-')"><xsl:text>0x041d Swedish</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'th' or starts-with($target-language, 'th-')"><xsl:text>0x041e Thai</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'tr' or starts-with($target-language, 'tr-')"><xsl:text>0x041f Turkish</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'uk' or starts-with($target-language, 'uk-')"><xsl:text>0x0422 Ukrainian</xsl:text></xsl:when>
  <!-- Use common assumptions about Chinese. -->
  <xsl:when test="$target-language = 'zh-cn'"><xsl:text>0x0804 Chinese (CHINA)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'zh-hans'"><xsl:text>0x0804 Chinese (CHINA)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'zh-tw'"><xsl:text>0x0404 Chinese (TAIWAN, PROVINCE OF CHINA)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'zh-hant'"><xsl:text>0x0404 Chinese (TAIWAN, PROVINCE OF CHINA)</xsl:text></xsl:when>
  <xsl:when test="$target-language = 'zh' or starts-with($target-language, 'zh-')"><xsl:text>0x0804 Chinese (CHINA)</xsl:text></xsl:when>
  <!-- DITA standard says untagged language is English. -->
  <xsl:otherwise><xsl:text>0x409 English (United States)</xsl:text></xsl:otherwise>
</xsl:choose>
<xsl:text>
Default topic=</xsl:text>
<!-- in a single map, get the first valid topic -->
<xsl:text/>
<xsl:apply-templates select="descendant::*[contains(@class, ' map/topicref ')][not(@processing-role='resource-only')][@href][(@href and (not(@format) or @format = 'dita')) or contains(@href,'.htm')][not(contains(@toc,'no'))][not(@processing-role='resource-only')][1]" mode="defaulttopic"/>
<xsl:text/>

<!-- Get the title, if possible -->
<!-- Using a single map, so get the title from that map -->
<xsl:choose>
  <xsl:when test="/*[contains(@class, ' bookmap/bookmap ')]/*[contains(@class, ' bookmap/booktitle ')]/*[contains(@class,' bookmap/mainbooktitle ')]">
    <xsl:text>Title=</xsl:text><xsl:value-of select="/*[contains(@class, ' bookmap/bookmap ')]/*[contains(@class, ' bookmap/booktitle ')]/*[contains(@class,' bookmap/mainbooktitle ')]"/>
  </xsl:when>
  <xsl:when test="/*[contains(@class, ' map/map ')]/*[contains(@class, ' topic/title ')]">
    <xsl:text>Title=</xsl:text><xsl:value-of select="/*[contains(@class, ' map/map ')]/*[contains(@class, ' topic/title ')]"/>
  </xsl:when>
  <xsl:when test="/*[contains(@class, ' map/map ')]/@title">
    <xsl:text>Title=</xsl:text><xsl:value-of select="/*[contains(@class, ' map/map ')]/@title"/>
  </xsl:when>
</xsl:choose>
</xsl:template>


<!-- *********************************************************************************
     Output the list of files that will be included in the output.
     ********************************************************************************* -->
<xsl:template name="output-filenames">
  <!-- Place all of the file names in a temp file. Then process the temp file,
       removing dupliates. -->
  <xsl:variable name="temp">
    <filelist>
      <xsl:apply-templates/>
    </filelist>
  </xsl:variable>
    
<xsl:text>

[FILES]
</xsl:text>
  <xsl:apply-templates select="$temp/filelist/*" mode="tempfile">
    <xsl:sort select="@href"/>
  </xsl:apply-templates>
  <xsl:if test="string-length($INCLUDEFILE)>0">
<xsl:text>
#include </xsl:text><xsl:value-of select="$INCLUDEFILE"/><xsl:text>
</xsl:text>
  </xsl:if>
</xsl:template>

<!-- *********************************************************************************
     If asked, create the alias and map sections.
     The HTML Help program creates an empty [INFOTYPES] tag at the bottom of each
     project, so we will also create one.
     ********************************************************************************* -->
<xsl:template name="end-hhp">
<xsl:if test="string-length($HELPALIAS)>0">
<xsl:text>
[ALIAS]
#include </xsl:text><xsl:value-of select="$HELPALIAS"/><xsl:text>
</xsl:text>
</xsl:if>
<xsl:if test="string-length($HELPMAP)>0">
<xsl:text>
[MAP]
#include </xsl:text><xsl:value-of select="$HELPMAP"/><xsl:text>
</xsl:text>
</xsl:if>
<xsl:text>

[INFOTYPES]

</xsl:text>
</xsl:template>

<!-- *********************************************************************************
     Set up the HHP file, and send filenames to the proper section.
     ********************************************************************************* -->
<xsl:template match="/">
  <xsl:call-template name="setup-options"/>
  <xsl:call-template name="output-filenames"/>
  <xsl:call-template name="end-hhp"/>
</xsl:template>

<!-- *********************************************************************************
     If this is one map from a list, process the contents. Otherwise, output the HHP
     wrapper around the contents. When the contents are processed, they will generate
     a list of all XHTML files referenced by this map.
     ********************************************************************************* -->
<xsl:template match="/*[contains(@class, ' map/map ')]">
  <xsl:param name="pathFromMaplist"/>
  <xsl:apply-templates>
    <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
  </xsl:apply-templates>
</xsl:template>

<!-- *********************************************************************************
     If this topic should be included in navigation, output the referenced file,
     and process the children; otherwise, skip the topicref. Topics are considered
     invalid when @scope=external, or when the href does not point to a DITA or HTML file.
     ********************************************************************************* -->
<xsl:template match="*[contains(@class, ' map/topicref ')]">
  <xsl:param name="pathFromMaplist"/>
  <xsl:variable name="thisFilename">
    <xsl:if test="@href and not ((ancestor-or-self::*/@type)[last()]='external') and not((ancestor-or-self::*/@scope)[last()]='external')
            and not(@processing-role='resource-only')">
      <xsl:choose>
        <!-- For dita files, change the extension; for HTML files, output the name as-is. Use the copy-to value first. -->
        <xsl:when test="@copy-to and (not(@format) or @format = 'dita')">
          <xsl:value-of select="$pathFromMaplist"/>
          <xsl:call-template name="replace-extension">
            <xsl:with-param name="filename" select="@copy-to"/>
            <xsl:with-param name="extension" select="$OUTEXT"/>
            <xsl:with-param name="ignore-fragment" select="true()"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="@href and (not(@format) or @format = 'dita')">
          <xsl:value-of select="$pathFromMaplist"/>
          <xsl:call-template name="replace-extension">
            <xsl:with-param name="filename" select="@href"/>
            <xsl:with-param name="extension" select="$OUTEXT"/>
            <xsl:with-param name="ignore-fragment" select="true()"/>
          </xsl:call-template>
        </xsl:when>
        <!-- For local HTML files, add any path from the maplist -->
        <xsl:when test="contains(@href,'.htm') and not(@scope='external')"><xsl:value-of select="$pathFromMaplist"/><xsl:value-of select="@href"/></xsl:when>
        <xsl:when test="contains(@href,'.htm')"><xsl:value-of select="$pathFromMaplist"/><xsl:value-of select="@href"/></xsl:when>
      </xsl:choose>
    </xsl:if>
  </xsl:variable>
  <xsl:if test="string-length($thisFilename)>0">
    <file>
      <xsl:attribute name="href">
        <xsl:call-template name="removeAllExtraRelpath">
          <xsl:with-param name="remainingPath" select="$thisFilename"/>
        </xsl:call-template>
      </xsl:attribute>
    </file>
  </xsl:if>
  <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]">
    <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
  </xsl:apply-templates>
</xsl:template>

<!-- *********************************************************************************
     Process the default topic for this HHP file to get the filename. Same as above,
     except that we know @href is specified, and we do not process children.
     ********************************************************************************* -->
<xsl:template match="*[contains(@class, ' map/topicref ')]" mode="defaulttopic">
  <xsl:param name="pathFromMaplist"/>
  <xsl:choose>
    <!-- If copy-to is specified, that copy should be used in place of the original -->
    <xsl:when test="@copy-to and (not(@format) or @format = 'dita')">
      <xsl:if test="not(@scope='external')"><xsl:value-of select="$pathFromMaplist"/></xsl:if>
      <xsl:call-template name="replace-extension">
        <xsl:with-param name="filename" select="@copy-to"/>
        <xsl:with-param name="extension" select="$OUTEXT"/>
        <xsl:with-param name="ignore-fragment" select="true()"/>
      </xsl:call-template>
      <xsl:text>
</xsl:text></xsl:when>
    <!-- For dita files, change the extension to OUTEXT -->
    <xsl:when test="@href and (not(@format) or @format = 'dita')">
      <xsl:if test="not(@scope='external')"><xsl:value-of select="$pathFromMaplist"/></xsl:if>
      <xsl:call-template name="replace-extension">
        <xsl:with-param name="filename" select="@href"/>
        <xsl:with-param name="extension" select="$OUTEXT"/>
        <xsl:with-param name="ignore-fragment" select="true()"/>
      </xsl:call-template>
      <xsl:text>
</xsl:text></xsl:when>
    <!-- For local HTML files, add any path from the maplist -->
    <xsl:when test="contains(@href,'.htm') and not(@scope='external')">
      <xsl:value-of select="$pathFromMaplist"/><xsl:value-of select="@href"/><xsl:text>
</xsl:text></xsl:when>
    <!-- For external HTML files, output the name as-is -->
    <xsl:when test="contains(@href,'.htm')"><xsl:value-of select="@href"/><xsl:text>
</xsl:text></xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="*[contains(@class, ' map/reltable ')]">
  <xsl:param name="pathFromMaplist"/>
  <xsl:apply-templates select="*[contains(@class, ' map/relrow ')]/*[contains(@class, ' map/relcell ')]/*[contains(@class, ' map/topicref ')]">
    <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
  </xsl:apply-templates>
</xsl:template>

<!-- Process the temp file that creates each name; remove duplicates -->
<xsl:template match="/filelist/file" mode="tempfile">
  <xsl:variable name="testhref" select="@href"/>
  <xsl:if test="not(preceding-sibling::*[@href=$testhref])">
    <xsl:value-of select="@href"/><xsl:text>
</xsl:text>
  </xsl:if>
</xsl:template>

<!-- These are here just to prevent accidental fallthrough -->
<xsl:template match="*[contains(@class, ' map/navref ')]"/>
<xsl:template match="*[contains(@class, ' map/anchor ')]"/>
<xsl:template match="*[contains(@class, ' map/topicmeta ')]"/>
<xsl:template match="text()"/>

<xsl:template match="*">
  <xsl:apply-templates/>
</xsl:template>

<!-- Template to get the relative path to a map -->
<xsl:template name="getRelativePath">
  <xsl:param name="remainingPath" select="@file"/>
  <xsl:choose>
    <xsl:when test="contains($remainingPath,'/')">
      <xsl:value-of select="substring-before($remainingPath,'/')"/><xsl:text>/</xsl:text>
      <xsl:call-template name="getRelativePath">
        <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'/')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="contains($remainingPath,'\')">
      <xsl:value-of select="substring-before($remainingPath,'\')"/><xsl:text>/</xsl:text>
      <xsl:call-template name="getRelativePath">
        <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'\')"/>
      </xsl:call-template>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<!-- Remove all extra relpaths (as in './multiple/directories/../../other/') -->
<xsl:template name="removeAllExtraRelpath">
  <xsl:param name="remainingPath"><xsl:value-of select="@href"/></xsl:param>
  <xsl:variable name="firstRoundRemainingPath">
    <xsl:call-template name="removeExtraRelpath">
      <xsl:with-param name="remainingPath">
        <xsl:value-of select="$remainingPath"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="secondRoundRemainingPath">
    <xsl:call-template name="removeExtraRelpath">
      <xsl:with-param name="remainingPath">
        <xsl:value-of select="$firstRoundRemainingPath"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:variable>
  <xsl:choose>
    <xsl:when test="contains($secondRoundRemainingPath, '../') and not($firstRoundRemainingPath=$secondRoundRemainingPath)">
      <xsl:call-template name="removeAllExtraRelpath">
        <xsl:with-param name="remainingPath" select="$secondRoundRemainingPath"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$secondRoundRemainingPath"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Remove extra relpaths (as in abc/../def) -->
<xsl:template name="removeExtraRelpath">
  <xsl:param name="remainingPath"><xsl:value-of select="@href"/></xsl:param>
  <xsl:choose>
    <xsl:when test="contains($remainingPath,'\')">
      <xsl:call-template name="removeExtraRelpath">
        <xsl:with-param name="remainingPath"><xsl:value-of 
          select="substring-before($remainingPath,'\')"/>/<xsl:value-of 
          select="substring-after($remainingPath,'\')"/></xsl:with-param>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="starts-with($remainingPath,'./')">
      <xsl:call-template name="removeExtraRelpath">
        <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'./')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="not(contains($remainingPath,'../'))"><xsl:value-of select="$remainingPath"/></xsl:when>
    <xsl:when test="not(starts-with($remainingPath,'../')) and
                    starts-with(substring-after($remainingPath,'/'),'../')">
      <xsl:call-template name="removeExtraRelpath">
        <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'../')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="contains($remainingPath,'/')">
      <xsl:value-of select="substring-before($remainingPath,'/')"/>/<xsl:text/>
      <xsl:call-template name="removeExtraRelpath">
        <xsl:with-param name="remainingPath" select="substring-after($remainingPath,'/')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$remainingPath"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
