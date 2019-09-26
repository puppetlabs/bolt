<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<!-- Refactoring completed March and April 2007. The code now contains 
     numerous hooks that can be overridden using modes. Specifically,
     the most important modes will be those that control what is inherited or
     pulled from a topic:
mode="mappull:inherit-attribute"
     * Used when inheriting attributes. An override can ensure that (for example) @format
       does not inherit from <specializedElement>. See <xsl:template match="@*" mode="mappull:inherit-attribute">
       for samples.
mode="mappull:get-stuff_get-type"
     * Used when getting the type value for a topicref. To turn off type retrieval, match the element with
       this mode and return #none#
mode="mappull:verify-type-value"
     * Used to verify a hard-coded type is correct. An override can turn off this verification for
       specific elements or for all elements.
mode="mappull:get-stuff_get-navtitle"
     * Used when setting the navtitle for a topicref. Typically pulls the title from the target, if
       possible, to replace the local navtitle.
mode="mappull:getmetadata_linktext", mode="mappull:getmetadata_shortdesc"
     * Used when creating the linktext or shortdesc. Overriding will remove the <linktext> or
       <shortdesc> element even if it was specified in the map.

Other modes can be found within the code, and may or may not prove useful for overrides.
     -->
<!-- 20090903 RDA: added <?ditaot gentext?> and <?ditaot linktext?> PIs for RFE 1367897.
                   Allows downstream processes to identify original text vs. generated link text. -->

<xsl:stylesheet version="2.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:mappull="http://dita-ot.sourceforge.net/ns/200704/mappull"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                xmlns:saxon="http://saxon.sf.net/"
                exclude-result-prefixes="xs dita-ot mappull ditamsg saxon">
  <xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-textonly.xsl"/>
  <!-- Define the error message prefix identifier -->
  <xsl:variable name="msgprefix" as="xs:string">DOTX</xsl:variable>
  <!-- If converting to PDF, never try to pull info from targets with print="no" -->
  <xsl:param name="FINALOUTPUTTYPE" select="''" as="xs:string"/>
  <xsl:param name="conserve-memory" select="'false'" as="xs:string"/>
  
  <!-- Equivalent to document() but may discard documents from cache when instructed and able. -->
  <xsl:function name="dita-ot:document" as="node()*">
    <xsl:param name="url-sequence" as="item()*"/>
    <xsl:param name="base-node" as="node()"/>
    <xsl:choose>
      <xsl:when test="$conserve-memory eq 'true'" use-when="function-available('saxon:discard-document')">
        <xsl:sequence select="saxon:discard-document(document($url-sequence, $base-node))"/>
      </xsl:when>
      <!-- use xsl:when instead of xsl:otherwise because of preceding @use-when -->
      <xsl:when test="true()">
        <xsl:sequence select="document($url-sequence, $base-node)"/>    
      </xsl:when>
    </xsl:choose>
  </xsl:function>
  
  <xsl:key name="topic-by-id" match="*[contains(@class,' topic/topic ')]" use="@id"/>

  <!-- Find the relative path to another topic or map -->
  <xsl:template name="find-relative-path">
    <xsl:param name="remainingpath" as="xs:string"/>
    <xsl:if test="contains($remainingpath,'/')">
      <xsl:value-of select="substring-before($remainingpath,'/')"/>
      <xsl:text>/</xsl:text>
      <xsl:call-template name="find-relative-path">
        <xsl:with-param name="remainingpath" select="substring-after($remainingpath,'/')"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Default rule for processing a topicref element. -->
  <xsl:template match="*[contains(@class, ' map/topicref ')]">
    <xsl:param name="relative-path" as="xs:string">#none#</xsl:param>
    <!-- used for mapref source ditamap to retain the relative path information of the target ditamap -->
    <xsl:param name="parent-linking" as="xs:string">#none#</xsl:param>
    <!-- used for mapref target to see whether @linking should be override by the source of mapref -->
    <xsl:param name="parent-toc" as="xs:string">#none#</xsl:param>
    <!-- used for mapref target to see whether @toc should be override by the source of mapref -->
    <xsl:param name="parent-processing-role" as="xs:string">#none#</xsl:param>
    
    <!--need to create these variables regardless, for passing as a parameter to get-stuff template-->
        <xsl:variable name="type" as="xs:string">
          <xsl:call-template name="inherit"><xsl:with-param name="attrib">type</xsl:with-param></xsl:call-template>
        </xsl:variable>
        <xsl:variable name="print" as="xs:string">
          <xsl:call-template name="inherit"><xsl:with-param name="attrib">print</xsl:with-param></xsl:call-template>
        </xsl:variable>
        <xsl:variable name="format" as="xs:string">
          <xsl:call-template name="inherit"><xsl:with-param name="attrib">format</xsl:with-param></xsl:call-template>
        </xsl:variable>
        <xsl:variable name="scope" as="xs:string">
          <xsl:call-template name="inherit"><xsl:with-param name="attrib">scope</xsl:with-param></xsl:call-template>
        </xsl:variable>

        <!--copy self-->
        <xsl:copy>
          <!--copy existing explicit attributes-->
          <xsl:apply-templates select="@* except @href"/>

          <xsl:apply-templates select="." mode="mappull:set-href-attribute">
            <xsl:with-param name="relative-path" select="$relative-path"/>
          </xsl:apply-templates>

          <!--copy inheritable attributes that aren't already explicitly defined-->
          <!--@type|@importance|@linking|@toc|@print|@search|@format|@scope-->
          <!--need to create type variable regardless, for passing as a parameter to getstuff template-->
          <xsl:if test="(:not(@type) and :)$type!='#none#'">
            <xsl:attribute name="type"><xsl:value-of select="$type"/></xsl:attribute>
          </xsl:if>
          <!-- FIXME: importance is not inheretable per http://docs.oasis-open.org/dita/v1.2/os/spec/archSpec/cascading-in-a-ditamap.html -->
          <!--xsl:if test="not(@importance)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">importance</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <!-- if it's in target of mapref override the current linking attribute when parent linking is none -->
          <xsl:if test="$parent-linking='none'">
            <xsl:attribute name="linking">none</xsl:attribute>
          </xsl:if>
          <xsl:if test="(:not(@linking) and :)not($parent-linking='none')">
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">linking</xsl:with-param></xsl:apply-templates>
          </xsl:if>
          <!-- if it's in target of mapref override the current toc attribute when parent toc is no -->
          <xsl:if test="$parent-toc='no'">
            <xsl:attribute name="toc">no</xsl:attribute>
          </xsl:if>
          <xsl:if test="(:not(@toc) and :)not($parent-toc='no')">
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">toc</xsl:with-param></xsl:apply-templates>
          </xsl:if>
          <xsl:if test="$parent-processing-role='resource-only'">
            <xsl:attribute name="processing-role">resource-only</xsl:attribute>
          </xsl:if>
          <xsl:if test="(:not(@processing-role) and :)not($parent-processing-role='resource-only')">
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">processing-role</xsl:with-param></xsl:apply-templates>
          </xsl:if>
          <xsl:if test="(:not(@print) and :)$print!='#none#'">
            <xsl:attribute name="print"><xsl:value-of select="$print"/></xsl:attribute>
          </xsl:if>
          <!--xsl:if test="not(@search)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">search</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <xsl:if test="(:not(@format) and :)$format!='#none#'">
            <xsl:attribute name="format"><xsl:value-of select="$format"/></xsl:attribute>
          </xsl:if>
          <xsl:if test="(:not(@scope) and :)$scope!='#none#'">
            <xsl:attribute name="scope"><xsl:value-of select="$scope"/></xsl:attribute>
          </xsl:if>
          <!--xsl:if test="not(@audience)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">audience</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <!--xsl:if test="not(@platform)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">platform</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <!--xsl:if test="not(@product)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">product</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <!--xsl:if test="not(@rev)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">rev</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <!--xsl:if test="not(@otherprops)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">otherprops</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <!--xsl:if test="not(@props)"-->
            <xsl:apply-templates select="." mode="mappull:inherit-and-set-attribute"><xsl:with-param name="attrib">props</xsl:with-param></xsl:apply-templates>
          <!--/xsl:if-->
          <!--grab type, text and metadata, as long there's an href to grab from, and it's not inaccessible-->
          <xsl:choose>
            <xsl:when test="@href=''">
              <xsl:apply-templates select="." mode="ditamsg:empty-href"/>
            </xsl:when>
            <xsl:when test="$print='no' and ($FINALOUTPUTTYPE='PDF' or $FINALOUTPUTTYPE='IDD')"/>
            <xsl:when test="@href">
              <xsl:call-template name="get-stuff">
                <xsl:with-param name="type" select="$type"/>
                <xsl:with-param name="scope" select="$scope"/>
                <xsl:with-param name="format" select="$format"/>
              </xsl:call-template>
            </xsl:when>
          </xsl:choose>
          <!--apply templates to children-->
          <xsl:apply-templates  select="*|comment()|processing-instruction()">
            <xsl:with-param name="parent-linking" select="$parent-linking"/>
            <xsl:with-param name="parent-toc" select="$parent-toc"/>
            <xsl:with-param name="relative-path" select="$relative-path"/>
          </xsl:apply-templates>
        </xsl:copy>
        
  </xsl:template>

  <!-- Set the href value, with modifications as appropriate -->
  <xsl:template match="*" mode="mappull:set-href-attribute" as="attribute()?">
    <xsl:param name="relative-path" as="xs:string">#none#</xsl:param>
    <xsl:if test="@href and not(@href='')">
      <xsl:attribute name="href">
        <xsl:choose>
          <xsl:when test="not(contains(@href,'://') or @scope='external' or $relative-path='#none#' or $relative-path='')">
            <xsl:value-of select="concat($relative-path, @href)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@href"/>
          </xsl:otherwise>
        </xsl:choose>            
      </xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- RDA: FUNCTIONS TO IMPROVE OVERRIDE CAPABILITIES FOR INHERITING ATTRIBUTES -->

  <!-- Original function: processing moved to matching templates with mode="mappull:inherit-attribute"
       Result is the same as in original code: if the attribute is present or inherited, return
       the inherited value; if it is not available in the ancestor-or-self tree, return #none# -->
  <xsl:template name="inherit" as="xs:string">
    <xsl:param name="attrib" as="xs:string"/>
    <xsl:apply-templates select="." mode="mappull:inherit-from-self-then-ancestor">
      <xsl:with-param name="attrib" select="$attrib"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Similar to the template above, but saves duplicated processing by setting the
       inherited attribute when the inherited value != #none# -->
  <xsl:template match="*" mode="mappull:inherit-and-set-attribute" as="attribute()?">
    <xsl:param name="attrib" as="xs:string"/>
    <xsl:variable name="inherited-value" as="xs:string">
      <xsl:apply-templates select="." mode="mappull:inherit-from-self-then-ancestor">
        <xsl:with-param name="attrib" select="$attrib"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:if test="$inherited-value!='#none#'">
      <xsl:attribute name="{$attrib}"><xsl:value-of select="$inherited-value"/></xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- Match the attribute which we are trying to inherit.
       If an attribute should never inherit, add this template to an override:
       <xsl:template match="@attributeName" mode="mappull:inherit-attribute"/>
       If an attribute should never inherit for a specific element, add this to an override:
       <xsl:template match="*[contains(@class,' spec/elem ')]/@attributeName" mode="mappull:inherit-attribute"/>  -->
  <xsl:template match="@*" mode="mappull:inherit-attribute" as="xs:string">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:variable name="single-value-attrib"
                select="('linking', 'toc', 'print', 'search', 'format', 'scope', 'type', 'xml:lang', 'dir', 'translate', 'processing-role')"
                as="xs:string*"/>

  <!-- Some elements should not pass an attribute to children, but they SHOULD set the
       attribute locally. If it is specified locally, use it. Otherwise, go to parent. This
       template should ONLY be called from the actual element that is trying to set attributes.
       For example, when <specialGroup format="group"> should keep @format locally, but should
       never pass that value to children. -->
  <xsl:template match="*" mode="mappull:inherit-from-self-then-ancestor" as="xs:string">
    <xsl:param name="attrib" as="xs:string"/>
    <xsl:variable name="attrib-here" select="@*[local-name()=$attrib]" as="attribute()?"/>
    <xsl:choose>
      <xsl:when test="$attrib = $single-value-attrib or ancestor-or-self::*[@cascade][1]/@cascade = 'nomerge'">
        <xsl:choose>
          <!-- Any time the attribute is specified on this element, use it -->
          <xsl:when test="$attrib-here!=''"><xsl:value-of select="$attrib-here"/></xsl:when>
          <!-- Otherwise, use normal inheritance fallback -->
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="mappull:inherit-attribute">
              <xsl:with-param name="attrib" select="$attrib"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="inherited" as="xs:string">
          <xsl:apply-templates select="." mode="mappull:merge-inherit-attribute">
            <xsl:with-param name="attrib" select="$attrib"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:variable name="values" select="tokenize(normalize-space($inherited), '\s')" as="xs:string*"/>
        <xsl:value-of select="if (exists($values)) then string-join($values, ' ') else '#none#'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="mappull:merge-inherit-attribute" as="xs:string">
    <xsl:param name="attrib" as="xs:string"/>
    <xsl:value-of>
      <xsl:value-of select="@*[local-name() = $attrib]"/>
      <xsl:text> </xsl:text>
      <xsl:if test="ancestor-or-self::*[@cascade][1]/@cascade = 'merge'">
        <xsl:apply-templates select="parent::*" mode="mappull:merge-inherit-attribute">
          <xsl:with-param name="attrib" select="$attrib"/>
        </xsl:apply-templates>
      </xsl:if>
    </xsl:value-of>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/relcell ')]" mode="mappull:merge-inherit-attribute" as="xs:string">
    <xsl:param name="attrib" as="xs:string"/>
    <xsl:value-of>
      <xsl:value-of select="@*[local-name() = $attrib]"/>
      <xsl:text> </xsl:text>
      <xsl:apply-templates select="parent::*" mode="mappull:merge-inherit-attribute">
        <xsl:with-param name="attrib" select="$attrib"/>
      </xsl:apply-templates>
      <xsl:text> </xsl:text>
      <xsl:variable name="position" select="1 + count(preceding-sibling::*)" as="xs:integer"/>
      <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][$position ]" mode="mappull:merge-inherit-attribute">
        <xsl:with-param name="attrib" select="$attrib"/>
      </xsl:apply-templates>
    </xsl:value-of>
  </xsl:template>

  <!-- Match an element when trying to inherit an attribute. Put the value of the attribute in $attrib-here.
       * If the attribute is present and should be used ($attrib=here!=''), then use it
       * If we are at the root element, attribute can't be inherited, so return #none#
       * If in relcell: try to inherit from self, row, or column, then move to table
       * Anything else, move on to parent                                                     -->
  <xsl:template match="*" mode="mappull:inherit-attribute" as="xs:string?">
    <!--@importance|@linking|@toc|@print|@search|@format|@scope-->
    <xsl:param name="attrib" as="xs:string"/>
    <xsl:variable name="attrib-here" as="xs:string?">
      <xsl:apply-templates select="@*[local-name()=$attrib]" mode="mappull:inherit-attribute"/>
    </xsl:variable>
    <xsl:choose>
      <!-- Any time the attribute is specified on this element, use it -->
      <xsl:when test="$attrib-here!=''"><xsl:value-of select="$attrib-here"/></xsl:when>
      <!-- If this is not the first time thru the map, all attributes are already inherited, so do not check ancestors -->
      <xsl:when test="/processing-instruction()[name()='reparse']">#none#</xsl:when>
      <!-- No ancestors left to check, so the value is not available. -->
      <xsl:when test="not(parent::*)">#none#</xsl:when>
      <!-- When in a relcell, check inheritance in this order: row, then colspec,
           then proceed normally with the table. The value is not specified here on the entry,
           or it would have been caught in the first xsl:when test. -->
      <xsl:when test="contains(@class,' map/relcell ')">
        <xsl:variable name="position" select="1+count(preceding-sibling::*)" as="xs:integer"/>
        <xsl:variable name="row" as="xs:string?">
          <xsl:apply-templates select=".." mode="mappull:inherit-one-level"><xsl:with-param name="attrib" select="$attrib"/></xsl:apply-templates>
        </xsl:variable>
        <xsl:variable name="colspec" as="xs:string?">
          <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]/*[contains(@class, ' map/relheader ')]/*[contains(@class, ' map/relcolspec ')][position()=$position ]" mode="mappull:inherit-one-level">
            <xsl:with-param name="attrib" select="$attrib"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="$row!=''"><xsl:value-of select="$row"/></xsl:when>
          <xsl:when test="$colspec!=''"><xsl:value-of select="$colspec"/></xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="ancestor::*[contains(@class, ' map/reltable ')]" mode="mappull:inherit-attribute">
              <xsl:with-param name="attrib" select="$attrib"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="@cascade">
        <xsl:apply-templates select="parent::*" mode="mappull:inherit-from-self-then-ancestor">
          <xsl:with-param name="attrib" select="$attrib"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="parent::*" mode="mappull:inherit-attribute">
          <xsl:with-param name="attrib" select="$attrib"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Check if an attribute can be inherited from a specific element, without
       looking at ancestors. For example, check if can inherit from relrow; next
       comes relcolspec, which is not in the normal inheritance order. -->
  <xsl:template match="*" mode="mappull:inherit-one-level" as="xs:string?">
    <xsl:param name="attrib" as="xs:string"/>
    <xsl:if test="@*[local-name()=$attrib]">
      <xsl:value-of select="@*[local-name()=$attrib]"/>
    </xsl:if>
  </xsl:template>

  <!-- RDA: END FUNCTIONS TO IMPROVE OVERRIDE CAPABILITIES FOR INHERITING ATTRIBUTES -->
  
  <!-- Redirected to mode template to allow overrides -->
  <xsl:template name="verify-type-value">
    <xsl:param name="type" as="xs:string"/>         <!-- Specified type on the topicref -->
    <xsl:param name="actual-class" as="xs:string"/> <!-- Class value on the target element -->
    <xsl:param name="actual-name" as="xs:string"/>  <!-- Name of the target element -->
    <xsl:param name="WORKDIR" as="xs:string">
      <xsl:apply-templates select="/processing-instruction('workdir-uri')[1]" mode="get-work-dir"/>
    </xsl:param>
    <xsl:apply-templates select="." mode="mappull:verify-type-value">
      <xsl:with-param name="type" select="$type"/>
      <xsl:with-param name="actual-class" select="$actual-class"/>
      <xsl:with-param name="actual-name" select="$actual-name"/>
      <xsl:with-param name="WORKDIR" select="$WORKDIR"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Verify that a locally specified type value is correct. If a reference is
       typed as a topic, inform the user that a more specific value may be used.
       If a reference is typed as a concept, warn the user: generated links to
       this topic will incorrectly treat it as a concept. -->
  <xsl:template match="*" mode="mappull:verify-type-value">
    <xsl:param name="type" as="xs:string"/>          <!-- Specified type on the topicref -->
    <xsl:param name="actual-class" as="xs:string"/>  <!-- Class value on the target element -->
    <xsl:param name="actual-name" as="xs:string"/>   <!-- Name of the target element -->
    <xsl:param name="WORKDIR" as="xs:string">
      <xsl:apply-templates select="/processing-instruction('workdir-uri')[1]" mode="get-work-dir"/>
    </xsl:param>
    <xsl:choose>
      <!-- The type is correct; concept typed as concept, newtype defined as newtype -->
      <xsl:when test="$type=$actual-name"/>
      <!-- If the actual class contains the specified type; reference can be called topic,
           specializedReference can be called reference -->
      <xsl:when test="contains($actual-class,concat(' ',$type,'/',$type,' '))">
        <!-- commented out for bug:1771123 start -->
        <!--xsl:apply-templates select="." mode="ditamsg:type-mismatch-info">
          <xsl:with-param name="type" select="$type"/>
          <xsl:with-param name="actual-name" select="$actual-name"/>
        </xsl:apply-templates-->
        <!-- commented out for bug:1771123 end -->
      </xsl:when>
      <!-- Otherwise: incorrect type is specified -->
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="ditamsg:type-mismatch-warning">
          <xsl:with-param name="type" select="$type"/>
          <xsl:with-param name="actual-name" select="$actual-name"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- RDA: BREAK GET-STUFF TEMPLATE APART INTO OVERRIDEABLE CHUNKS -->

  <!--Figure out what portion of the href attribute is the path to the file-->
  <xsl:template match="*" mode="mappull:get-stuff_file" as="xs:string">
    <xsl:param name="WORKDIR" as="xs:string">
      <xsl:apply-templates select="/processing-instruction('workdir-uri')[1]" mode="get-work-dir"/>
    </xsl:param>
    <xsl:choose>
      <!--an absolute path using a scheme, eg http, plus a fragment identifier - grab the part before the fragment-->
      <xsl:when test="contains(@href,'://') and contains(@href,'#')">
        <xsl:value-of select="substring-before(@href,'#')"/>
      </xsl:when>
      <!--an absolute path using a scheme, with no fragment - grab the whole url-->
      <xsl:when test="contains(@href,'://')">
        <xsl:value-of select="@href"/>
      </xsl:when>
      <!--a relative path including a fragment identifier - add the working directory, plus the part before the fragment-->
      <xsl:when test="contains(@href,'#')">
        <xsl:value-of select="concat($WORKDIR, substring-before(@href,'#'))"/>
      </xsl:when>
      <!--otherwise a relative path with no fragment, add the working directory plus the url-->
      <xsl:otherwise>
        <xsl:value-of select="concat($WORKDIR, @href)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Figure out whether this points to a topic within a file, or the first topic -->
  <xsl:template match="*" mode="mappull:get-stuff_topic-position" as="xs:string">
    <xsl:choose>
       <xsl:when test="contains(@href,'#')">otherfile</xsl:when>
       <xsl:otherwise>firstinfile</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Figure out which topic it points to, if not the first -->
  <xsl:template match="*" mode="mappull:get-stuff_topic-id" as="xs:string">
    <xsl:choose>
      <xsl:when test="contains(@href,'#')"><xsl:value-of select="substring-after(@href,'#')"/></xsl:when>
      <xsl:otherwise>#none#</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Set the class value used to search for a target. If no type is specified, use topic; otherwise use the specified type. -->
  <xsl:template match="*" mode="mappull:get-stuff_target-classval" as="xs:string">
    <xsl:param name="type" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$type='#none#'"> topic/topic </xsl:when>
      <xsl:otherwise><xsl:value-of select="concat(' ', $type, '/', $type, ' ')"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Grab type from the target topic if it's not defined locally-->
  <xsl:template match="*" mode="mappull:get-stuff_get-type" as="attribute()?">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="scope" as="xs:string"/>
    <xsl:param name="topicpos" as="xs:string"/>
    <xsl:param name="format" as="xs:string"/>
    <xsl:param name="file" as="xs:string"/>
    <xsl:param name="classval" as="xs:string"/>
    <xsl:param name="topicid" as="xs:string"/>
    <xsl:param name="doc" as="document-node()?"/>
    <xsl:choose>
      <xsl:when test="$type='#none#'">
        <xsl:choose>
          <xsl:when test="@href=''"/>
          <xsl:when test="$scope='external' or $scope='peer' or not($format='#none#' or $format='dita')">
            <!-- do nothing - type is unavailable-->
          </xsl:when>

          <!--finding type based on name of the target element in a particular topic in another file-->
          <xsl:when test="$topicpos='otherfile'">
            <xsl:variable name="target" select="if (exists($doc)) then (key('topic-by-id', $topicid, $doc)[1]) else ()" as="element()?"/>
            <xsl:choose>
              <xsl:when test="$target[contains(@class, $classval)]">
                <xsl:attribute name="type">
                  <xsl:value-of select="local-name($target[contains(@class, $classval)])"/>
                </xsl:attribute>
              </xsl:when>
              <xsl:when test="$topicid!='#none#' and not($target[contains(@class, ' topic/topic ')])">
                <!-- topicid does not point to a valid topic -->
                <xsl:call-template name="output-message">
                  <xsl:with-param name="id" select="'DOTX061W'"/>
                  <xsl:with-param name="msgparams">%1=<xsl:value-of select="$topicid"/></xsl:with-param>
                </xsl:call-template>
              </xsl:when>
              <xsl:otherwise><!-- do nothing - omit attribute--></xsl:otherwise>
            </xsl:choose>
          </xsl:when>

          <!--finding type based on name of the target element in the first topic in another file-->
          <xsl:when test="$topicpos='firstinfile'">
            <xsl:choose>
              <xsl:when test="($doc//*[contains(@class, ' topic/topic ')])[1]">
                <xsl:attribute name="type">
                  <xsl:value-of select="local-name(($doc//*[contains(@class, $classval)])[1])"/>
                </xsl:attribute>
              </xsl:when>
              <xsl:otherwise><!-- do nothing - omit attribute--></xsl:otherwise>
            </xsl:choose>
          </xsl:when>

          <xsl:otherwise><!--never happens - both values for topicpos are tested--></xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- Type is set locally for a dita topic; warn if it is not correct. -->
      <xsl:when test="$scope!='external' and $scope!='peer' and ($format='#none#' or $format='dita')">
        <xsl:variable name="target" select="if (exists($doc)) then (key('topic-by-id', $topicid, $doc)[1]) else ()" as="element()?"/>
        <xsl:if test="$topicid!='#none#' and not($target[contains(@class, ' topic/topic ')])">
          <!-- topicid does not point to a valid topic -->
          <xsl:call-template name="output-message">
            <xsl:with-param name="id" select="'DOTX061W'"/>
            <xsl:with-param name="msgparams">%1=<xsl:value-of select="$topicid"/></xsl:with-param>
          </xsl:call-template>
        </xsl:if>
        <xsl:choose>
          <!--finding type based on name of the target elemenkt in a particular topic in another file-->
          <xsl:when test="$topicpos='otherfile' and $target[contains(@class, ' topic/topic ')]">
            <xsl:call-template name="verify-type-value">
              <xsl:with-param name="type" select="$type"/>
              <xsl:with-param name="actual-class" select="$target[contains(@class, ' topic/topic ')][1]/@class"/>
              <xsl:with-param name="actual-name" select="local-name($target[contains(@class, ' topic/topic ')][1])"/>
            </xsl:call-template>
          </xsl:when>

          <!--finding type based on name of the target element in the first topic in another file-->
          <xsl:when test="$topicpos='firstinfile' and $doc//*[contains(@class, ' topic/topic ')]">
            <xsl:call-template name="verify-type-value">
              <xsl:with-param name="type" select="$type"/>
              <xsl:with-param name="actual-class" select="($doc//*[contains(@class, ' topic/topic ')])[1]/@class"/>
              <xsl:with-param name="actual-name" select="local-name(($doc//*[contains(@class, ' topic/topic ')])[1])"/>
            </xsl:call-template>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- Get the navtitle from the target topic, if available. -->
  <xsl:template match="*" mode="mappull:get-stuff_get-navtitle" as="item()*">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="scope" as="xs:string"/>
    <xsl:param name="topicpos" as="xs:string"/>
    <xsl:param name="format" as="xs:string"/>
    <xsl:param name="file" as="xs:string"/>
    <xsl:param name="classval" as="xs:string"/>
    <xsl:param name="topicid" as="xs:string"/>
    <xsl:param name="doc" as="document-node()?"/>
    <xsl:choose>
      <!--if it's external and not dita, use the href as fallback-->
      <xsl:when
        test="$scope='external' and not($format='dita')">
        <xsl:choose>
          <xsl:when test="*/*[contains(@class,' topic/navtitle ')]">
            <xsl:value-of select="*/*[contains(@class,' topic/navtitle ')]"/>
          </xsl:when>
          <xsl:when test="@navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
          <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
            <xsl:copy-of select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]/node()"/>
          </xsl:when>
          <xsl:when test="*/*[contains(@class,' map/linktext ')]">
            <xsl:value-of select="*/*[contains(@class,' map/linktext ')]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@href"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!--if it's external and dita, leave it undefined as fallback, so the file extension can be processed in the final output stage-->
      <xsl:when test="$scope='external'">
        <xsl:choose>
          <xsl:when test="*/*[contains(@class,' topic/navtitle ')]">
            <xsl:value-of select="*/*[contains(@class,' topic/navtitle ')]"/>
          </xsl:when>
          <xsl:when test="@navtitle">
            <xsl:value-of select="@navtitle"/>
          </xsl:when>
          <xsl:when test="*/*[contains(@class,' map/linktext ')]">
            <xsl:value-of select="*/*[contains(@class,' map/linktext ')]"/>
          </xsl:when>
          <xsl:otherwise>#none#</xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$scope='peer'">
        <xsl:choose>
          <xsl:when test="*/*[contains(@class,' topic/navtitle ')]">
            <xsl:value-of select="*/*[contains(@class,' topic/navtitle ')]"/>
          </xsl:when>          
          <xsl:when test="@navtitle">
            <xsl:value-of select="@navtitle"/>
          </xsl:when>
          <xsl:when test="*/*[contains(@class,' map/linktext ')]">
            <xsl:value-of select="*/*[contains(@class,' map/linktext ')]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>#none#</xsl:text>
            <xsl:apply-templates select="." mode="ditamsg:missing-navtitle-peer"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- skip resource-only image files -->
      <xsl:when test="not($format = 'dita' or $format = '#none#') and 
        ancestor-or-self::*[@processing-role][1][@processing-role = 'resource-only']"/>
      <xsl:when test="not($format='#none#' or $format='dita')">
        <xsl:apply-templates select="." mode="mappull:get-navtitle-for-non-dita"/>
      </xsl:when>
      <xsl:when test="@href=''"/>
      <!--grabbing text from a particular topic in another file-->
      <xsl:when test="$topicpos='otherfile'">
        <xsl:variable name="target" select="if (exists($doc)) then (key('topic-by-id', $topicid, $doc)[1]) else ()" as="element()?"/>
        <xsl:choose>
          <xsl:when
            test="$target[contains(@class, $classval)]/*[contains(@class, ' topic/titlealts ')]/*[contains(@class, ' topic/navtitle ')]">
            <xsl:apply-templates
              select="($target[contains(@class, $classval)])[1]/*[contains(@class, ' topic/titlealts ')]/*[contains(@class, ' topic/navtitle ')]"
              mode="get-title-content"/>
          </xsl:when>
          <xsl:when
            test="$target[contains(@class, $classval)]/*[contains(@class, ' topic/title ')]">
            <xsl:apply-templates
              select="($target[contains(@class, $classval)])[1]/*[contains(@class, ' topic/title ')]"
              mode="get-title-content"/>
          </xsl:when>
          <xsl:when
            test="$target[contains(@class, ' topic/topic ')]/*[contains(@class, ' topic/title ')]">
            <xsl:apply-templates
              select="($target[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/title ')]"
              mode="get-title-content"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="mappull:navtitle-fallback"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!--grabbing text from the first topic in another file-->
      <xsl:when test="$topicpos='firstinfile'">
        <xsl:choose>
          <xsl:when
            test="$doc//*[contains(@class, ' topic/topic ')][1]/*[contains(@class, ' topic/titlealts ')]/*[contains(@class, ' topic/navtitle ')]">
            <xsl:apply-templates
              select="($doc//*[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/titlealts ')]/*[contains(@class, ' topic/navtitle ')]"
              mode="get-title-content"/>
          </xsl:when>
          <xsl:when
            test="$doc//*[contains(@class, ' topic/topic ')][1]/*[contains(@class, ' topic/title ')]">
            <xsl:apply-templates
              select="($doc//*[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/title ')]"
              mode="get-title-content"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="mappull:navtitle-fallback"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <!--both topicpos values have been tested - no way to fire this-->
        <xsl:value-of select="@href"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- This template is used to pull the type and navtitle from a topic. -->
  <xsl:template name="get-stuff">
    <xsl:param name="type" as="xs:string">#none#</xsl:param>
    <xsl:param name="scope" as="xs:string">#none#</xsl:param>
    <xsl:param name="format" as="xs:string">#none#</xsl:param>
    <xsl:param name="WORKDIR" as="xs:string">
      <xsl:apply-templates select="/processing-instruction('workdir-uri')[1]" mode="get-work-dir"/>
    </xsl:param>
    <xsl:variable name="locktitle" as="xs:string">
      <xsl:call-template name="inherit">
        <xsl:with-param name="attrib">locktitle</xsl:with-param>
      </xsl:call-template>
    </xsl:variable>
    <!--figure out what portion of the href is the path to the file-->
    <xsl:variable name="file-origin" as="xs:string">
      <xsl:apply-templates select="." mode="mappull:get-stuff_file">
        <xsl:with-param name="WORKDIR" select="$WORKDIR"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="file" as="xs:string">
      <xsl:call-template name="replace-blank">
        <xsl:with-param name="file-origin">
          <xsl:value-of select="$file-origin"/>
        </xsl:with-param>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="topicpos" as="xs:string">
      <xsl:apply-templates select="." mode="mappull:get-stuff_topic-position"/>
    </xsl:variable>
    <xsl:variable name="topicid" as="xs:string">
      <xsl:apply-templates select="." mode="mappull:get-stuff_topic-id"/>
    </xsl:variable>

    <xsl:variable name="classval" as="xs:string">
      <xsl:apply-templates select="." mode="mappull:get-stuff_target-classval"><xsl:with-param name="type" select="$type"/></xsl:apply-templates>
    </xsl:variable>

    <xsl:variable name="doc"
                  select="if (($format = ('dita', '#none#')) and
                              ($scope = ('local', '#none#')))
                          then dita-ot:document($file, /)
                          else ()"
                  as="document-node()?"/>

    <!--type-->
    <xsl:apply-templates select="." mode="mappull:get-stuff_get-type">
      <xsl:with-param name="type" select="$type"/>
      <xsl:with-param name="scope" select="$scope"/>
      <xsl:with-param name="topicpos" select="$topicpos"/>
      <xsl:with-param name="format" select="$format"/>
      <xsl:with-param name="file" select="$file"/>
      <xsl:with-param name="classval" select="$classval"/>
      <xsl:with-param name="topicid" select="$topicid"/>
      <xsl:with-param name="doc" select="$doc"/>
    </xsl:apply-templates>

    <!--navtitle-->
    <xsl:variable name="navtitle" as="item()*">
      <xsl:choose>
        <xsl:when test="(not(*/*[contains(@class,' topic/navtitle ')]) and not(@navtitle)) or not($locktitle='yes')">
          <xsl:apply-templates select="." mode="mappull:get-stuff_get-navtitle">
            <xsl:with-param name="type" select="$type"/>
            <xsl:with-param name="scope" select="$scope"/>
            <xsl:with-param name="topicpos" select="$topicpos"/>
            <xsl:with-param name="format" select="$format"/>
            <xsl:with-param name="file" select="$file"/>
            <xsl:with-param name="classval" select="$classval"/>
            <xsl:with-param name="topicid" select="$topicid"/>
            <xsl:with-param name="doc" select="$doc"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>#none#</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <!-- Process the topicmeta, or create a topicmeta container if one does not exist -->
    <xsl:choose>
      <xsl:when test="*[contains(@class,' map/topicmeta ')]">
        <xsl:for-each select="*[contains(@class,' map/topicmeta ')]">
          <xsl:copy>
            <xsl:copy-of select="@class"/>
            <xsl:for-each select="parent::*">
              <xsl:call-template name="getmetadata">
                <xsl:with-param name="type" select="$type"/>
                <xsl:with-param name="file" select="$file"/>
                <xsl:with-param name="topicpos" select="$topicpos"/>
                <xsl:with-param name="topicid" select="$topicid"/>
                <xsl:with-param name="classval" select="$classval"/>
                <xsl:with-param name="scope" select="$scope"/>
                <xsl:with-param name="format" select="$format"/>
                <xsl:with-param name="navtitle" select="$navtitle"/>
                <xsl:with-param name="doc" select="$doc"/>
              </xsl:call-template>
            </xsl:for-each>
          </xsl:copy>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <topicmeta class="- map/topicmeta ">
          <xsl:call-template name="getmetadata">
            <xsl:with-param name="type" select="$type"/>
            <xsl:with-param name="file" select="$file"/>
            <xsl:with-param name="topicpos" select="$topicpos"/>
            <xsl:with-param name="topicid" select="$topicid"/>
            <xsl:with-param name="classval" select="$classval"/>
            <xsl:with-param name="scope" select="$scope"/>
            <xsl:with-param name="format" select="$format"/>
            <xsl:with-param name="navtitle" select="$navtitle"/>
            <xsl:with-param name="doc" select="$doc"/>
          </xsl:call-template>
        </topicmeta>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- This template is used when the navtitle cannot be retrieved. -->
  <xsl:template match="*" mode="mappull:navtitle-fallback" as="xs:string?">
    <xsl:choose>
      <xsl:when test="@navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
      <xsl:when test="*/*[contains(@class,' map/linktext ')]">
        <xsl:value-of select="*/*[contains(@class,' map/linktext ')]"/>
        <xsl:apply-templates select="." mode="ditamsg:using-linktext-for-navtitle"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>#none#</xsl:text>
        <xsl:apply-templates select="." mode="ditamsg:cannot-retrieve-navtitle"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="navtitle-fallback">
    <xsl:apply-templates select="." mode="mappull:navtitle-fallback"/>
  </xsl:template>

  <!-- Set the navtitle when pointing to a non-DITA resource. -->
  <xsl:template match="*" mode="mappull:get-navtitle-for-non-dita" as="xs:string?">
    <xsl:choose>
      <xsl:when test="@navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="@href"/>
        <xsl:apply-templates select="." mode="ditamsg:missing-navtitle-non-dita"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Set the link text when pointing to a non-DITA resource. -->
  <xsl:template match="*" mode="mappull:get-linktext-for-non-dita">
    <xsl:choose>
      <xsl:when test="@navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="@href"/>
        <xsl:apply-templates select="." mode="ditamsg:missing-navtitle-and-linktext-non-dita"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Set the linktext from a topic, unless specified within the topicref. -->
  <xsl:template match="*" mode="mappull:getmetadata_linktext" as="node()*">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="scope" as="xs:string">#none#</xsl:param>
    <xsl:param name="format" as="xs:string">#none#</xsl:param>
    <xsl:param name="file" as="xs:string"/>
    <xsl:param name="topicpos" as="xs:string"/>
    <xsl:param name="topicid" as="xs:string"/>
    <xsl:param name="classval" as="xs:string"/>
    <xsl:param name="doc" as="document-node()?"/>
    <xsl:choose>
      <!-- If linktext is already specified, use that -->
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]">
        <xsl:apply-templates select="." mode="mappull:add-usertext-PI"/>
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="linktext" as="xs:string?">
          <xsl:choose>
            <!--if it's external and not dita, use the href as fallback-->
            <xsl:when test="$scope='external' and not($format='dita')">
              <xsl:apply-templates select="." mode="mappull:get-linktext_external-and-non-dita"/>
            </xsl:when>
            <!--if it's external and dita, leave empty as fallback, so that the final output process can handle file extension-->
            <xsl:when test="$scope='external'">
              <xsl:apply-templates select="." mode="mappull:get-linktext_external-dita"/>
            </xsl:when>
            <xsl:when test="$scope='peer'">
              <xsl:apply-templates select="." mode="mappull:get-linktext_peer-dita"/>
            </xsl:when>
            <!-- skip resource-only image files -->
            <xsl:when test="not($format = 'dita' or $format = '#none#') and 
              ancestor-or-self::*[@processing-role][1][@processing-role = 'resource-only']"/>
            <xsl:when test="not($format='#none#' or $format='dita')">
              <xsl:apply-templates select="." mode="mappull:get-linktext-for-non-dita"/>
            </xsl:when>
            <xsl:when test="@href=''">#none#</xsl:when>

            <!--grabbing text from a particular topic in another file-->
            <xsl:when test="$topicpos='otherfile'">
              <xsl:variable name="target" select="if (exists($doc)) then (key('topic-by-id', $topicid, $doc)[1]) else ()" as="element()?"/>
              <xsl:choose>
                <xsl:when test="$target[contains(@class, $classval)]/*[contains(@class, ' topic/title ')]">
                  <xsl:variable name="grabbed-value" as="xs:string">
                    <xsl:value-of>
                      <xsl:apply-templates select="($target[contains(@class, $classval)])[1]/*[contains(@class, ' topic/title ')]" mode="text-only"/>
                    </xsl:value-of>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($grabbed-value)"/>
                </xsl:when>
                <xsl:when test="$target[contains(@class, ' topic/topic ')]/*[contains(@class, ' topic/title ')]">
                  <xsl:variable name="grabbed-value" as="xs:string">
                    <xsl:value-of>
                      <xsl:apply-templates select="($target[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/title ')]" mode="text-only"/>
                    </xsl:value-of>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($grabbed-value)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="linktext-fallback"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <!--grabbing text from the first topic in another file-->
            <xsl:when test="$topicpos='firstinfile'">
              <xsl:choose>
                <xsl:when test="$doc//*[contains(@class, ' topic/topic ')][1]/*[contains(@class, ' topic/title ')]">
                  <xsl:variable name="grabbed-value" as="xs:string">
                    <xsl:value-of>
                     <xsl:apply-templates select="($doc//*[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/title ')]" mode="text-only"/>
                    </xsl:value-of>
                  </xsl:variable>
                  <xsl:value-of select="normalize-space($grabbed-value)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="linktext-fallback"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <xsl:otherwise>#none#<!--never happens - both possible values for topicpos are tested--></xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:if test="not($linktext='#none#')">
          <xsl:apply-templates select="." mode="mappull:add-gentext-PI"/>
          <linktext class="- map/linktext ">
            <xsl:copy-of select="$linktext"/>
          </linktext>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- The following series of templates are used to set link text when the target
       cannot be used. The mode name describes each specific condition.-->
  <xsl:template match="*" mode="mappull:get-linktext_external-and-non-dita">
    <xsl:choose>
      <xsl:when test="@navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="@href"/></xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*" mode="mappull:get-linktext_external-dita">
    <xsl:choose>
      <xsl:when test="@navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise>#none#</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*" mode="mappull:get-linktext_peer-dita">
    <xsl:choose>
      <xsl:when test="@navtitle"><xsl:value-of select="@navtitle"/></xsl:when>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>#none#</xsl:text>
        <xsl:apply-templates select="." mode="ditamsg:missing-navtitle-and-linktext-peer"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Retrieve the shortdesc from a topic, unless specified within the topicmeta -->
  <xsl:template match="*" mode="mappull:getmetadata_shortdesc" as="node()*">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="scope" as="xs:string">#none#</xsl:param>
    <xsl:param name="format" as="xs:string">#none#</xsl:param>
    <xsl:param name="file" as="xs:string"/>
    <xsl:param name="topicpos" as="xs:string"/>
    <xsl:param name="topicid" as="xs:string"/>
    <xsl:param name="classval" as="xs:string"/>
    <xsl:param name="doc" as="document-node()?"/>
    <xsl:variable name="map-uri" as="xs:anyURI" select="base-uri(.)"/>
    <xsl:choose>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/shortdesc ')]">
        <xsl:apply-templates select="." mode="mappull:add-usershortdesc-PI"/>
        <xsl:apply-templates
          select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/shortdesc ')]"/>
      </xsl:when>
      <xsl:when
        test="$scope='external' or $scope='peer' or not($format='#none#' or $format='dita')">
        <!-- do nothing - shortdesc is unavailable-->
      </xsl:when>
      <!--try retrieving from a particular topic in another file-->
      <xsl:when test="$topicpos='otherfile'">
        <xsl:variable name="target" select="if (exists($doc)) then (key('topic-by-id', $topicid, $doc)[1]) else ()" as="element()?"/>
        <xsl:if
            test="($target[contains(@class, $classval)])[1]/*[contains(@class, ' topic/shortdesc ')]|
                  ($target[contains(@class, $classval)])[1]/*[contains(@class, ' topic/abstract ')]/*[contains(@class, ' topic/shortdesc ')]">
          <xsl:apply-templates select="." mode="mappull:add-genshortdesc-PI"/>
          <shortdesc class="- map/shortdesc ">
            <xsl:apply-templates select="($target[contains(@class, $classval)])[1]/*[contains(@class, ' topic/shortdesc ')] |
                                         ($target[contains(@class, $classval)])[1]/*[contains(@class, ' topic/abstract ')]/*[contains(@class, ' topic/shortdesc ')]" mode="copy-shortdesc">
              <xsl:with-param name="map-uri" select="$map-uri" tunnel="yes"/>
            </xsl:apply-templates>
          </shortdesc>
        </xsl:if>
      </xsl:when>
      <!--try retrieving from the first topic in another file-->
      <xsl:when test="$topicpos='firstinfile'">
        <xsl:if
            test="($doc//*[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/shortdesc ')]|
                  ($doc//*[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/abstract ')]/*[contains(@class, ' topic/shortdesc ')]">
          <xsl:apply-templates select="." mode="mappull:add-genshortdesc-PI"/>
          <shortdesc class="- map/shortdesc ">
            <xsl:apply-templates
              select="($doc//*[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/shortdesc ')]|
                      ($doc//*[contains(@class, ' topic/topic ')])[1]/*[contains(@class, ' topic/abstract ')]/*[contains(@class, ' topic/shortdesc ')]"
              mode="copy-shortdesc">
              <xsl:with-param name="map-uri" select="$map-uri" tunnel="yes"/>
            </xsl:apply-templates>
          </shortdesc>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <!--shortdesc optional - no warning if absent-->
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Get the linktext and shortdesc from a target topic. These are pulled from
       the topic when not specified locally, and when the target can be used. -->
  <xsl:template name="getmetadata">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="scope" as="xs:string">#none#</xsl:param>
    <xsl:param name="format" as="xs:string">#none#</xsl:param>
    <xsl:param name="file" as="xs:string"/>
    <xsl:param name="topicpos" as="xs:string"/>
    <xsl:param name="topicid" as="xs:string"/>
    <xsl:param name="classval" as="xs:string"/>
    <xsl:param name="navtitle" as="item()*"/>
    <xsl:param name="doc" as="document-node()?"/>
    <!--navtitle-->
    <xsl:choose>
      <xsl:when test="not($navtitle='#none#')">
        <navtitle class="- topic/navtitle ">
          <xsl:copy-of select="$navtitle"/>
        </navtitle>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates
          select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]"
        />
      </xsl:otherwise>
    </xsl:choose>
    <!--linktext-->
    <xsl:apply-templates select="." mode="mappull:getmetadata_linktext">
      <xsl:with-param name="type" select="$type"/>
      <xsl:with-param name="scope" select="$scope"/>
      <xsl:with-param name="format" select="$format"/>
      <xsl:with-param name="file" select="$file"/>
      <xsl:with-param name="topicpos" select="$topicpos"/>
      <xsl:with-param name="topicid" select="$topicid"/>
      <xsl:with-param name="classval" select="$classval"/>
      <xsl:with-param name="doc" select="$doc"/>
    </xsl:apply-templates>
    <!--shortdesc-->
    <xsl:apply-templates select="." mode="mappull:getmetadata_shortdesc">
      <xsl:with-param name="type" select="$type"/>
      <xsl:with-param name="scope" select="$scope"/>
      <xsl:with-param name="format" select="$format"/>
      <xsl:with-param name="file" select="$file"/>
      <xsl:with-param name="topicpos" select="$topicpos"/>
      <xsl:with-param name="topicid" select="$topicid"/>
      <xsl:with-param name="classval" select="$classval"/>
      <xsl:with-param name="doc" select="$doc"/>
    </xsl:apply-templates>
    <!--metadata to be written - if we add logic at some point to pull metadata from topics into the map-->
    <xsl:apply-templates
      select="*[contains(@class, ' map/topicmeta ')]/*[not(contains(@class, ' map/linktext '))][not(contains(@class, ' map/shortdesc '))][not(contains(@class, ' topic/navtitle '))]|
      *[contains(@class, ' map/topicmeta ')]/processing-instruction()"
    />
  </xsl:template>

  <!-- When the link text cannot be retrieved for a topic, use this to determine fallback text. -->
  <xsl:template match="*" mode="mappull:linktext-fallback" as="node()*">
    <xsl:choose>
      <xsl:when test="@navtitle">
        <xsl:value-of select="@navtitle"/>
        <xsl:apply-templates select="." mode="ditamsg:no-linktext-using-fallback"/>
      </xsl:when>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <xsl:copy-of select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]/node()"/>
        <xsl:apply-templates select="." mode="ditamsg:no-linktext-using-fallback"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>#none#</xsl:text>
        <xsl:apply-templates select="." mode="ditamsg:no-linktext-no-fallback"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="linktext-fallback">
    <xsl:apply-templates select="." mode="mappull:linktext-fallback"/>
  </xsl:template>

  <xsl:template match="*|text()|processing-instruction()" mode="text-only" as="xs:string?">
    <!-- Redirect to common dita-ot module -->
    <xsl:value-of>
      <xsl:apply-templates select="." mode="dita-ot:text-only"/>
    </xsl:value-of>
  </xsl:template>
  <xsl:template match="*|@*|comment()|processing-instruction()|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|comment()|processing-instruction()|text()"/>
    </xsl:copy>
  </xsl:template>


 
  
  <!--following template is here to make sure topicmeta gets copied in cases where the topicref has no href (and therefore the getstuff template isn't called-->
  <xsl:template match="*[contains(@class, ' map/topicref ')]/*[contains(@class, ' map/topicmeta ')]">
    <!--<xsl:variable name="format">
      <xsl:for-each select="parent::*">
        <xsl:call-template name="inherit"><xsl:with-param name="attrib">format</xsl:with-param></xsl:call-template>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="scope">
      <xsl:for-each select="parent::*">
        <xsl:call-template name="inherit"><xsl:with-param name="attrib">scope</xsl:with-param></xsl:call-template>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="type">
      <xsl:for-each select="parent::*">
        <xsl:call-template name="inherit"><xsl:with-param name="attrib">type</xsl:with-param></xsl:call-template>
      </xsl:for-each>
    </xsl:variable>-->
    <xsl:if test="not(parent::*/@href)">
      <xsl:copy><xsl:apply-templates select="@*|*|comment()|processing-instruction()"/></xsl:copy>
    </xsl:if>
  </xsl:template>
  <xsl:template match="*[contains(@class,' map/map ')]">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|comment()|processing-instruction()|text()"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="text()" mode="copy-shortdesc" as="xs:string">
    <xsl:value-of select="translate(.,'&#xA;',' ')"/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' topic/shortdesc ')]" mode="copy-shortdesc">
    <xsl:if test="preceding-sibling::*[contains(@class,' topic/shortdesc ')]">
      <!-- In an abstract, and this is not the first -->
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:apply-templates select="node()" mode="copy-shortdesc"/>
  </xsl:template>
  
  <xsl:template match="@id" mode="copy-shortdesc"/>
  
  <xsl:template match="@href" mode="copy-shortdesc">
    <xsl:param name="map-uri" as="xs:anyURI?" tunnel="yes"/>
    <xsl:variable name="abs-href" select="resolve-uri(., base-uri(.))" as="xs:anyURI"/>
    <xsl:variable name="href" select="dita-ot:relativize($map-uri, $abs-href)" as="xs:anyURI"/>
    <xsl:attribute name="{name()}" select="$href"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/indexterm ')]" mode="copy-shortdesc" />
  
  <xsl:template match="@* | node()" mode="copy-shortdesc" name="copy-shortdesc" priority="-10">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="copy-shortdesc"/>
    </xsl:copy>
  </xsl:template>

  <!-- Make it easy to override messages. If a product wishes to change or hide
       specific messages, it can override these templates. Longer term, it would
       be good to move messages from each XSL file into a common location. -->
  <!-- Deprecated -->
  <xsl:template match="*" mode="ditamsg:unknown-extension">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX006E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <!-- Deprecated -->
  <xsl:template match="*" mode="ditamsg:incorect-inherited-format">
    <xsl:param name="format" as="xs:string"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX016W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$format"/>;%2=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:empty-href">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX017E'"/>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:type-mismatch-info">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="actual-name" as="xs:string"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX018I'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$type"/>;%2=<xsl:value-of select="$actual-name"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:type-mismatch-warning">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="actual-name" as="xs:string"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX019W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$type"/>;%2=<xsl:value-of select="$actual-name"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:missing-navtitle-peer">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX020E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:missing-navtitle-non-dita">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX021E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:using-linktext-for-navtitle">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX022W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:cannot-retrieve-navtitle">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX023W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:missing-navtitle-and-linktext-peer">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX024E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:missing-navtitle-and-linktext-non-dita">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX025E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:no-linktext-using-fallback">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX026W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:no-linktext-no-fallback">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX027W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="*[contains(@class,' topic/draft-comment ')]" mode="copy-shortdesc"/>

  <!-- Added for RFE 1367897 -->
  <xsl:template match="*" mode="mappull:add-gentext-PI" as="processing-instruction()">
    <xsl:processing-instruction name="ditaot">gentext</xsl:processing-instruction>
  </xsl:template>
  <xsl:template match="*" mode="mappull:add-usertext-PI" as="processing-instruction()">
    <xsl:processing-instruction name="ditaot">usertext</xsl:processing-instruction>
  </xsl:template>
  <!-- Shortdesc version added for RFE 3001750 -->
  <xsl:template match="*" mode="mappull:add-genshortdesc-PI" as="processing-instruction()">
    <xsl:processing-instruction name="ditaot">genshortdesc</xsl:processing-instruction>
  </xsl:template>
  <xsl:template match="*" mode="mappull:add-usershortdesc-PI" as="processing-instruction()">
    <xsl:processing-instruction name="ditaot">usershortdesc</xsl:processing-instruction>
  </xsl:template>
 
  <!-- Added on 20110125 for bug:Navtitle Construction Does not Preserve Markup - ID: 3157890  start -->
  <xsl:template match="*[contains(@class,' topic/title ')]|*[contains(@class, ' topic/navtitle ')]" mode="get-title-content">    
    <xsl:apply-templates select="*|comment()|processing-instruction()|text()" />  
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/title ')]//text() |
                       *[contains(@class,' topic/navtitle ')]//text()" >
    <xsl:if test="not(normalize-space(substring(., 1, 1)))">
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:value-of select="normalize-space(.)"/>
    <xsl:if test="not(normalize-space(substring(., string-length(.))))">
      <xsl:text> </xsl:text>
    </xsl:if>
  </xsl:template>
  
</xsl:stylesheet>
