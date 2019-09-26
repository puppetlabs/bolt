<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                exclude-result-prefixes="xs dita-ot dita2html ditamsg">



<!-- =========== OTHER STYLESHEET INCLUDES/IMPORTS =========== -->
<xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
<xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
<xsl:import href="plugin:org.dita.base:xsl/common/related-links.xsl"/>
<xsl:import href="plugin:org.dita.base:xsl/common/dita-textonly.xsl"/>
<xsl:include href="plugin:org.dita.xhtml:xsl/xslhtml/get-meta.xsl"/>
<xsl:include href="plugin:org.dita.xhtml:xsl/xslhtml/rel-links.xsl"/>

<!-- =========== OUTPUT METHOD =========== -->

<!-- XHTML output with XML syntax -->
<xsl:output method="xml"
            encoding="utf-8"
            indent="no"
/>


<!-- =========== DEFAULT VALUES FOR EXTERNALLY MODIFIABLE PARAMETERS =========== -->

<!-- /CSS = default CSS filename parameter ('')-->
<xsl:param name="CSS"/>
<xsl:param name="dita-css" select="'commonltr.css'"/> <!-- left to right languages -->
<xsl:param name="bidi-dita-css" select="'commonrtl.css'"/> <!-- bidirectional languages -->

<!-- Transform type, such as 'xhtml', 'htmlhelp', or 'eclipsehelp' -->
<xsl:param name="TRANSTYPE" select="'xhtml'"/>

<!-- default CSS path parameter (null)-->
<xsl:param name="CSSPATH"/>

<!-- Preserve DITA class ancestry in XHTML output; values are 'yes' or 'no' -->
<xsl:param name="PRESERVE-DITA-CLASS" select="'yes'"/>

<!-- the file name containing XHTML to be placed in the HEAD area
     (file name and extension only - no path). -->
<xsl:param name="HDF"/>

<!-- the file name containing XHTML to be placed in the BODY running-heading area
     (file name and extension only - no path). -->
<xsl:param name="HDR"/>

<!-- the file name containing XHTML to be placed in the BODY running-footing area
     (file name and extension only - no path). -->
<xsl:param name="FTR"/>

<!-- default "output artwork filenames" processing parameter ('no')-->
<xsl:param name="ARTLBL" select="'no'"/><!-- "no" and "yes" are valid values; non-'yes' is ignored -->

<!-- default "hide draft & cleanup content" processing parameter ('no' = hide them)-->
<xsl:param name="DRAFT" select="'no'"/><!-- "no" and "yes" are valid values; non-'yes' is ignored -->

<!-- default "hide index entries" processing parameter ('no' = hide them)-->
<xsl:param name="INDEXSHOW" select="'no'"/><!-- "no" and "yes" are valid values; non-'yes' is ignored -->

<!-- the year for the copyright -->
<xsl:param name="YEAR" select="format-date(current-date(), '[Y]')"/>

<!-- default "output extension" processing parameter ('.html')-->
<xsl:param name="OUTEXT" select="'.html'"/><!-- "htm" and "html" are valid values -->

<!-- the working directory that contains the document being transformed.
     Needed as a directory prefix for the @conref "document()" function calls.
     default is '../doc/')-->
  <xsl:param name="WORKDIR">
    <xsl:apply-templates select="/processing-instruction('workdir-uri')[1]" mode="get-work-dir"/>
  </xsl:param>

<!-- the path back to the project. Used for c.gif, delta.gif, css to allow user's to have
     these files in 1 location. -->
    <xsl:param name="PATH2PROJ">
        <xsl:apply-templates select="/processing-instruction('path2project-uri')[1]" mode="get-path2project"/>
    </xsl:param>
  
<!-- the file name (file name and extension only - no path) of the document being transformed.
     Needed to help with debugging.
     default is 'myfile.xml')-->
<xsl:param name="FILENAME"/>
<xsl:param name="FILEDIR"/>
<xsl:param name="CURRENTFILE" select="concat($FILEDIR, '/', $FILENAME)"/>

<!-- the file name containing filter/flagging/revision information
     (file name and extension only - no path).  - testfile: revflag.dita -->
<xsl:param name="FILTERFILE"/>

<!-- Debug mode - enables XSL debugging xsl-messages.
     Needed to help with debugging.
     default is 'no')-->
<xsl:param name="DBG" select="'no'"/> <!-- "no" and "yes" are valid values; non-'yes' is ignored -->

<!-- Switch to enable or disable the generation of default meta message in html header -->
<xsl:param name="genDefMeta" select="'no'"/>

<!-- Name of the keyref file that contains key definitions -->
<!-- Deprecated since 2.1 -->
<xsl:param name="KEYREF-FILE" select="concat($WORKDIR, $PATH2PROJ, 'keydef.xml')"/>
<!-- Deprecated since 2.1 -->
<xsl:variable name="keydefs" select="document($KEYREF-FILE)"/>
  
<xsl:param name="BASEDIR"/>
  
<xsl:param name="OUTPUTDIR"/>
  <!-- get destination dir with BASEDIR and OUTPUTDIR-->
  <xsl:variable name="desDir">
    <xsl:choose>
      <xsl:when test="not($BASEDIR)"/> <!-- If no filterfile leave empty -->
      <xsl:when test="starts-with($BASEDIR, 'file:')">
        <xsl:value-of select="translate(concat($BASEDIR, '/', $OUTPUTDIR, '/'), '\', '/')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="contains($OUTPUTDIR, ':\') or contains($OUTPUTDIR, ':/')">
            <xsl:value-of select="'file:/'"/><xsl:value-of select="concat($OUTPUTDIR, '/')"/>
          </xsl:when>
          <xsl:when test="starts-with($OUTPUTDIR, '/')">
            <xsl:value-of select="'file://'"/><xsl:value-of select="concat($OUTPUTDIR, '/')"/>
          </xsl:when>
          <xsl:when test="starts-with($BASEDIR, '/')">
            <xsl:text>file://</xsl:text><xsl:value-of select="concat($BASEDIR, '/', $OUTPUTDIR, '/')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>file:/</xsl:text><xsl:value-of select="translate(concat($BASEDIR, '/', $OUTPUTDIR, '/'), '\', '/')"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

<!-- =========== "GLOBAL" DECLARATIONS (see 35) =========== -->

<!-- The document tree of filterfile returned by document($FILTERFILE,/)-->
  <xsl:variable name="FILTERFILEURL">
    <xsl:choose>
      <xsl:when test="not($FILTERFILE)"/> <!-- If no filterfile leave empty -->
      <xsl:when test="starts-with($FILTERFILE, 'file:')">
        <xsl:value-of select="$FILTERFILE"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="starts-with($FILTERFILE, '/')">
            <xsl:text>file://</xsl:text><xsl:value-of select="$FILTERFILE"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>file:/</xsl:text><xsl:value-of select="$FILTERFILE"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  
<xsl:variable name="FILTERDOC"
              select="if (string-length($FILTERFILEURL) > 0)
                      then document($FILTERFILEURL, /)
                      else ()"/>
  
  <xsl:variable name="passthrough-attrs" as="element()*"
                select="$FILTERDOC/val/prop[@action = 'passthrough']"/>

<!-- Define a newline character -->
<xsl:variable name="newline"><xsl:text>
</xsl:text></xsl:variable>

<!--Check the file Url Definition of HDF HDR FTR-->
 <xsl:variable name="HDFFILE">
   <xsl:choose>
     <xsl:when test="not($HDF)"/> <!-- If no filterfile leave empty -->
     <xsl:when test="starts-with($HDF, 'file:')">
       <xsl:value-of select="$HDF"/>
     </xsl:when>
     <xsl:otherwise>
       <xsl:choose>
         <xsl:when test="starts-with($HDF, '/')">
           <xsl:text>file://</xsl:text><xsl:value-of select="$HDF"/>
         </xsl:when>
         <xsl:otherwise>
           <xsl:text>file:/</xsl:text><xsl:value-of select="$HDF"/>
         </xsl:otherwise>
       </xsl:choose>
     </xsl:otherwise>
   </xsl:choose>
 </xsl:variable>
  
  <xsl:variable name="HDRFILE">
    <xsl:choose>
      <xsl:when test="not($HDR)"/> <!-- If no filterfile leave empty -->
      <xsl:when test="starts-with($HDR, 'file:')">
        <xsl:value-of select="$HDR"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="starts-with($HDR, '/')">
            <xsl:text>file://</xsl:text><xsl:value-of select="$HDR"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>file:/</xsl:text><xsl:value-of select="$HDR"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
    </xsl:variable>
  
  <xsl:variable name="FTRFILE">
    <xsl:choose>
      <xsl:when test="not($FTR)"/> <!-- If no filterfile leave empty -->
      <xsl:when test="starts-with($FTR, 'file:')">
        <xsl:value-of select="$FTR"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="starts-with($FTR, '/')">
            <xsl:text>file://</xsl:text><xsl:value-of select="$FTR"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>file:/</xsl:text><xsl:value-of select="$FTR"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  
<!-- Define the error message prefix identifier -->
<!-- Deprecated since 2.3 -->
<xsl:variable name="msgprefix">DOTX</xsl:variable>

<!-- Filler for A-name anchors  - was &nbsp;-->
<xsl:variable name="afill"></xsl:variable>

<xsl:variable name="HTML_ID_SEPARATOR" select="'__'"/>

<!-- these elements are never processed in a conventional presentation. can be overridden. -->
<xsl:template match="*[contains(@class, ' topic/no-topic-nesting ')]"/>


<!-- =========== ROOT RULE (just fall through; no side effects for new delivery contexts =========== -->

<xsl:template match="/">
  <xsl:apply-templates/>
</xsl:template>


<!-- =========== NESTED TOPIC RULES =========== -->

<!-- This first template rule generates the outer-level shell for a delivery context.
     In an override stylesheet, the same call to "chapter-setup" must be issued to
     maintain the consistency of overall look'n'feel of the output HTML.
     Match on the first DITA element -or- the first root 'topic' element. -->
<xsl:template match="/dita | *[contains(@class, ' topic/topic ')]">
  <xsl:choose>
    <xsl:when test="not(parent::*)">
      <xsl:apply-templates select="." mode="root_element"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="child.topic"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Matches /dita or a root topic -->
<xsl:template match="*" mode="root_element" name="root_element">
  <xsl:call-template name="chapter-setup"/>
</xsl:template>

<!-- child topics get a div wrapper and fall through -->
<xsl:template match="*[contains(@class, ' topic/topic ')]" mode="child.topic" name="child.topic">
  <xsl:param name="nestlevel" as="xs:integer">
      <xsl:choose>
          <!-- Limit depth for historical reasons, could allow any depth. Previously limit was 5. -->
          <xsl:when test="count(ancestor::*[contains(@class, ' topic/topic ')]) > 9">9</xsl:when>
          <xsl:otherwise><xsl:sequence select="count(ancestor::*[contains(@class, ' topic/topic ')])"/></xsl:otherwise>
      </xsl:choose>
  </xsl:param>
  <article class="nested{$nestlevel}">
    <xsl:attribute name="aria-labelledby">
      <xsl:apply-templates select="*[contains(@class,' topic/title ')]" mode="return-aria-label-id"/>
    </xsl:attribute>
    <xsl:call-template name="gen-topic">
      <xsl:with-param name="nestlevel" select="$nestlevel"/>
    </xsl:call-template>
  </article>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template name="gen-topic">
  <xsl:param name="nestlevel" as="xs:integer">
      <xsl:choose>
          <!-- Limit depth for historical reasons, could allow any depth. Previously limit was 5. -->
          <xsl:when test="count(ancestor::*[contains(@class, ' topic/topic ')]) > 9">9</xsl:when>
          <xsl:otherwise><xsl:sequence select="count(ancestor::*[contains(@class, ' topic/topic ')])"/></xsl:otherwise>
      </xsl:choose>
  </xsl:param>
 <xsl:choose>
   <xsl:when test="parent::dita and not(preceding-sibling::*)">
     <!-- Do not reset xml:lang if it is already set on <html> -->
     <!-- Moved outputclass to the body tag -->
     <!-- Keep ditaval based styling at this point (replace DITA-OT 1.6 and earlier call to gen-style) -->
     <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
   </xsl:when>
   <xsl:otherwise>
     <xsl:call-template name="commonattributes">
       <xsl:with-param name="default-output-class" select="concat('nested', $nestlevel)"/>
     </xsl:call-template>
   </xsl:otherwise>
 </xsl:choose>
 <xsl:call-template name="gen-toc-id"/>
  <xsl:call-template name="setidaname"/>
  <xsl:apply-templates/>
</xsl:template>


<!-- NESTED TOPIC TITLES (sensitive to nesting depth, but are still processed for contained markup) -->
<!-- 1st level - topic/title -->
<!-- Condensed topic title into single template without priorities; use $headinglevel to set heading.
     If desired, somebody could pass in the value to manually set the heading level -->
<xsl:template match="*[contains(@class, ' topic/topic ')]/*[contains(@class, ' topic/title ')]">
  <xsl:param name="headinglevel" as="xs:integer">
      <xsl:choose>
          <xsl:when test="count(ancestor::*[contains(@class, ' topic/topic ')]) > 6">6</xsl:when>
          <xsl:otherwise><xsl:sequence select="count(ancestor::*[contains(@class, ' topic/topic ')])"/></xsl:otherwise>
      </xsl:choose>
  </xsl:param>
  <xsl:element name="h{$headinglevel}">
      <xsl:attribute name="class">topictitle<xsl:value-of select="$headinglevel"/></xsl:attribute>
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class">topictitle<xsl:value-of select="$headinglevel"/></xsl:with-param>
      </xsl:call-template>
      <xsl:attribute name="id"><xsl:apply-templates select="." mode="return-aria-label-id"/></xsl:attribute>
      <xsl:apply-templates/>
  </xsl:element>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/topic ')]/*[contains(@class, ' topic/title ')]" mode="return-aria-label-id">
  <xsl:choose>
    <xsl:when test="@id">
      <xsl:sequence select="dita-ot:generate-id(parent::*/@id, @id)"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>ariaid-title</xsl:text>
      <xsl:number count="*[contains(@class, ' topic/title ')][parent::*[contains(@class,' topic/topic ')]]" level="any"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Hide titlealts - they need to get pulled into the proper places -->
<xsl:template match="*[contains(@class, ' topic/titlealts ')]"/>


<!-- =========== BODY/SECTION (not sensitive to nesting depth) =========== -->

<xsl:template match="*[contains(@class, ' topic/body ')]" name="topic.body">
<div>
  <xsl:call-template name="commonattributes"/>
  <xsl:call-template name="setidaname"/>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <!-- here, you can generate a toc based on what's a child of body -->
  <!--xsl:call-template name="gen-sect-ptoc"/--><!-- Works; not always wanted, though; could add a param to enable it.-->

  <!-- Insert prev/next links. since they need to be scoped by who they're 'pooled' with, apply-templates in 'hierarchylink' mode to linkpools (or related-links itself) when they have children that have any of the following characteristics:
       - role=ancestor (used for breadcrumb)
       - role=next or role=previous (used for left-arrow and right-arrow before the breadcrumb)
       - importance=required AND no role, or role=sibling or role=friend or role=previous or role=cousin (to generate prerequisite links)
       - we can't just assume that links with importance=required are prerequisites, since a topic with eg role='next' might be required, while at the same time by definition not a prerequisite -->

  <!-- Added for DITA 1.1 "Shortdesc proposal" -->
  <!-- get the abstract para -->
  <xsl:apply-templates select="preceding-sibling::*[contains(@class, ' topic/abstract ')]" mode="outofline"/>
  
  <!-- get the shortdesc para -->
  <xsl:apply-templates select="preceding-sibling::*[contains(@class, ' topic/shortdesc ')]" mode="outofline"/>
  
  <!-- Insert pre-req links - after shortdesc - unless there is a prereq section about -->
  <xsl:apply-templates select="following-sibling::*[contains(@class, ' topic/related-links ')]" mode="prereqs"/>

  <xsl:apply-templates/>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
</div><xsl:value-of select="$newline"/>
</xsl:template>

<!-- Added for DITA 1.1 "Shortdesc proposal" -->
<xsl:template match="*[contains(@class, ' topic/abstract ')]">
  <xsl:if test="not(following-sibling::*[contains(@class, ' topic/body ')])">
    <xsl:apply-templates select="." mode="outofline"/>
    <xsl:apply-templates select="following-sibling::*[contains(@class, ' topic/related-links ')]" mode="prereqs"/>
  </xsl:if>
</xsl:template>

<!-- Added for DITA 1.1 "Shortdesc proposal" -->
<!-- called abstract processing - para at start of topic -->
<xsl:template match="*[contains(@class, ' topic/abstract ')]" mode="outofline">
  <div>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates/>
  </div><xsl:value-of select="$newline"/>
</xsl:template>

<!-- Updated for DITA 1.1 "Shortdesc proposal" -->
<!-- Added for SF 1363055: Shortdesc disappears when optional body is removed -->
<xsl:template match="*[contains(@class, ' topic/shortdesc ')]">
  <xsl:choose>
    <xsl:when test="parent::*[contains(@class, ' topic/abstract ')]">
      <xsl:apply-templates select="." mode="outofline.abstract"/>
    </xsl:when>
    <xsl:when test="not(following-sibling::*[contains(@class, ' topic/body ')])">    
      <xsl:apply-templates select="." mode="outofline"/>
      <xsl:apply-templates select="following-sibling::*[contains(@class, ' topic/related-links ')]" mode="prereqs"/>
    </xsl:when>
    <xsl:otherwise></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- called shortdesc processing when it is in abstract -->
<xsl:template match="*[contains(@class, ' topic/shortdesc ')]" mode="outofline.abstract">
  <xsl:choose>    
    <xsl:when test="exists(preceding-sibling::*[dita-ot:is-block(.)] | following-sibling::*[dita-ot:is-block(.)])">
      <p>
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates/>
      </p>
    </xsl:when>
    <xsl:otherwise>
      <xsl:if test="preceding-sibling::* | preceding-sibling::text()">
        <xsl:text> </xsl:text>
      </xsl:if>
      <span>
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates/>
      </span>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- called shortdesc processing - para at start of topic -->
<xsl:template match="*[contains(@class, ' topic/shortdesc ')]" mode="outofline">
  <p>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates/>
  </p><xsl:value-of select="$newline"/>
</xsl:template>

<!-- section processor - div with no generated title -->
<xsl:template match="*[contains(@class, ' topic/section ')]" name="topic.section">
  <section class="section">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="gen-toc-id"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="dita2html:section-heading"/>
    <xsl:apply-templates select="*[not(contains(@class, ' topic/title '))] | text() | comment() | processing-instruction()"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </section><xsl:value-of select="$newline"/>
</xsl:template>

<!-- example processor - div with no generated title -->
<xsl:template match="*[contains(@class, ' topic/example ')]" name="topic.example">
  <div class="example">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="gen-toc-id"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="dita2html:section-heading"/>
    <xsl:apply-templates select="*[not(contains(@class, ' topic/title '))] | text() | comment() | processing-instruction()"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </div><xsl:value-of select="$newline"/>
</xsl:template>

<!-- ===================================================================== -->

<!-- =========== BASIC BODY ELEMENTS =========== -->

<xsl:template match="*[contains(@class, ' topic/div ')]">
  <div>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates/>
  </div>
</xsl:template>

<!-- paragraphs -->
<xsl:template match="*[contains(@class, ' topic/p ')]" name="topic.p">
 <!-- To ensure XHTML validity, need to determine whether the DITA kids are block elements.
      If so, use div_class="p" instead of p -->
 <xsl:choose>
   <xsl:when test="descendant::*[dita-ot:is-block(.)]">
     <div class="p">
       <xsl:call-template name="commonattributes"/>
       <xsl:call-template name="setid"/>
       <xsl:apply-templates/>
     </div>
     </xsl:when>
  <xsl:otherwise>
  <p>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates/>
  </p>
  </xsl:otherwise>
 </xsl:choose><xsl:value-of select="$newline"/>
</xsl:template>

<!-- Left for users who call this template in an override -->
<xsl:template name="note">
  <xsl:apply-templates select="." mode="process.note"/>
</xsl:template>

<!-- Fixed SF Bug 1405184 "Note template for XHTML should be easier to override" -->
<!-- RFE 2703335 reduces duplicated code by adding common processing rules.
     To override all notes, match the note element's class attribute directly, as in this rule.
     To override a single note type, match the class with mode="process.note.(selected-type)"
     To override all notes except danger and caution, match the class with mode="process.note.common-processing" -->
<xsl:template match="*[contains(@class, ' topic/note ')]" name="topic.note">
  <xsl:call-template name="spec-title"/>
  <xsl:choose>
    <xsl:when test="@type = 'note'">
      <xsl:apply-templates select="." mode="process.note"/>
    </xsl:when>
    <xsl:when test="@type = 'tip'">
      <xsl:apply-templates select="." mode="process.note.tip"/>
    </xsl:when>
    <xsl:when test="@type = 'fastpath'">
      <xsl:apply-templates select="." mode="process.note.fastpath"/>
    </xsl:when>
    <xsl:when test="@type = 'important'">
      <xsl:apply-templates select="." mode="process.note.important"/>
    </xsl:when>
    <xsl:when test="@type = 'remember'">
      <xsl:apply-templates select="." mode="process.note.remember"/>
    </xsl:when>
    <xsl:when test="@type = 'restriction'">
      <xsl:apply-templates select="." mode="process.note.restriction"/>
    </xsl:when>
    <xsl:when test="@type = 'attention'">
      <xsl:apply-templates select="." mode="process.note.attention"/>
    </xsl:when>
    <xsl:when test="@type = 'caution'">
      <xsl:apply-templates select="." mode="process.note.caution"/>
    </xsl:when>
    <xsl:when test="@type = 'danger'">
      <xsl:apply-templates select="." mode="process.note.danger"/>
    </xsl:when>
    <xsl:when test="@type = 'warning'">
      <xsl:apply-templates select="." mode="process.note.warning"/>
    </xsl:when>
    <xsl:when test="@type = 'trouble'">
      <xsl:apply-templates select="." mode="process.note.trouble"/>
    </xsl:when>
    <xsl:when test="@type = 'other'">
      <xsl:apply-templates select="." mode="process.note.other"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="process.note"/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*" mode="process.note.common-processing">
  <xsl:param name="type" select="@type"/>
  <xsl:param name="title">
    <xsl:call-template name="getVariable">
      <!-- For the parameter, turn "note" into "Note", caution => Caution, etc -->
      <xsl:with-param name="id"
           select="concat(upper-case(substring($type, 1, 1)),
                          substring($type, 2))"/>
      </xsl:call-template>
  </xsl:param>
  <div class="{$type}">
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="$type"/>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <!-- Normal flags go before the generated title; revision flags only go on the content. -->
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/prop" mode="ditaval-outputflag"/>
    <span class="{$type}title">
      <xsl:value-of select="$title"/>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'ColonSymbol'"/>
      </xsl:call-template>
    </span>
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/revprop" mode="ditaval-outputflag"/>
    <xsl:apply-templates/>
    <!-- Normal end flags and revision end flags both go out after the content. -->
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </div>
</xsl:template>

<xsl:template match="*" mode="process.note">
  <xsl:apply-templates select="." mode="process.note.common-processing">
    <!-- Force the type to note, in case new unrecognized values are added
         before translations exist (such as Warning) -->
    <xsl:with-param name="type" select="'note'"/>
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="*" mode="process.note.tip">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>

<xsl:template match="*" mode="process.note.fastpath">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>

<xsl:template match="*" mode="process.note.important">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>

<xsl:template match="*" mode="process.note.remember">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>

<xsl:template match="*" mode="process.note.restriction">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>

<xsl:template match="*" mode="process.note.warning">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>

<xsl:template match="*" mode="process.note.attention">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>
  
<xsl:template match="*" mode="process.note.trouble">
  <xsl:apply-templates select="." mode="process.note.common-processing"/>
</xsl:template>

<xsl:template match="*" mode="process.note.other">
  <xsl:choose>
    <xsl:when test="@othertype">
      <xsl:apply-templates select="." mode="process.note.common-processing">
        <xsl:with-param name="type" select="'note'"/>
        <xsl:with-param name="title" select="string(@othertype)"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="process.note.common-processing">
        <xsl:with-param name="type" select="'note'"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Caution and Danger both use a div for the title, so they do not
     use the common note processing template. -->
<xsl:template match="*" mode="process.note.caution">
  <div class="cautiontitle">
    <xsl:call-template name="commonattributes"/>
    <xsl:attribute name="class">cautiontitle</xsl:attribute>
    <xsl:call-template name="setidaname"/>
    <!-- Normal flags go before the generated title; revision flags only go on the content. -->
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/prop" mode="ditaval-outputflag"/>
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="'Caution'"/>
    </xsl:call-template>
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="'ColonSymbol'"/>
    </xsl:call-template>
  </div>
  <div class="caution">
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'caution'"/>
    </xsl:call-template>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/revprop" mode="ditaval-outputflag"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </div>  
</xsl:template>

<xsl:template match="*" mode="process.note.danger">
  <div class="dangertitle">
    <xsl:call-template name="commonattributes"/>
    <xsl:attribute name="class">dangertitle</xsl:attribute>
    <xsl:call-template name="setidaname"/>
    <!-- Normal flags go before the generated title; revision flags only go on the content. -->
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/prop" mode="ditaval-outputflag"/>
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="'Danger'"/>
    </xsl:call-template>
  </div>
  <div class="danger">
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'danger'"/>
    </xsl:call-template>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/revprop" mode="ditaval-outputflag"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </div>
</xsl:template>

<!-- long quote (bibliographic association).
     @reftitle contains the citation for the excerpt.
     With a link if @href is used.  -->
<xsl:template match="*[contains(@class, ' topic/lq ')]" name="topic.lq">
  <blockquote>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates/>
    <xsl:choose>
      <xsl:when test="@href">
        <br/><div style="text-align:right"><a>
          <xsl:attribute name="href">
            <xsl:call-template name="href"/>
          </xsl:attribute>
          <xsl:choose>
            <xsl:when test="@type = 'external'">
              <xsl:attribute name="target">_blank</xsl:attribute>
            </xsl:when>
            <xsl:otherwise><!--nop - no target needed for internal or biblio types (OR-should internal force DITA xref-like processing? What is intent? @type is only internal/external/bibliographic) --></xsl:otherwise>
          </xsl:choose>
          <cite><xsl:choose>
            <xsl:when test="@reftitle"><xsl:value-of select="@reftitle"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="@href"/></xsl:otherwise>
          </xsl:choose></cite></a></div>
      </xsl:when>
      <xsl:when test="@reftitle"> <!-- Insert citation text -->
        <br/><div style="text-align:right"><cite><xsl:value-of select="@reftitle"/></cite></div>
      </xsl:when>
      <xsl:otherwise><!--nop - do nothing--></xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </blockquote><xsl:value-of select="$newline"/>
</xsl:template>


<!-- =========== SINGLE PART LISTS =========== -->
  
  <!-- Ignore empty lists with all content filtered out -->
  <xsl:template match="*[contains(@class, ' topic/ol ')][empty(*[contains(@class,' topic/li ')])]" priority="10"/>
  <xsl:template match="*[contains(@class, ' topic/ul ')][empty(*[contains(@class,' topic/li ')])]" priority="10"/>
  <xsl:template match="*[contains(@class, ' topic/sl ')][empty(*[contains(@class,' topic/sli ')])]" priority="10"/>

<!-- Unordered List -->
<!-- handle all levels thru browser processing -->
<xsl:template match="*[contains(@class, ' topic/ul ')]" name="topic.ul">
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <xsl:call-template name="setaname"/>
  <ul>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="@compact"/>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates/>
  </ul>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- Simple List -->
<!-- handle all levels thru browser processing -->
<xsl:template match="*[contains(@class, ' topic/sl ')]" name="topic.sl">
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <xsl:call-template name="setaname"/>
  <ul class="simple">
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'simple'"/>
    </xsl:call-template>
    <xsl:apply-templates select="@compact"/>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates/>
  </ul>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- Ordered List - 1st level - Handle levels 1 to 9 thru OL-TYPE attribution -->
<!-- Updated to use a single template, use count and mod to set the list type -->
<xsl:template match="*[contains(@class, ' topic/ol ')]" name="topic.ol">
  <xsl:variable name="olcount" select="count(ancestor-or-self::*[contains(@class, ' topic/ol ')])"/>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <xsl:call-template name="setaname"/>
  <ol>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="@compact"/>
    <xsl:choose>
      <xsl:when test="$olcount mod 3 = 1"/>
      <xsl:when test="$olcount mod 3 = 2"><xsl:attribute name="type">a</xsl:attribute></xsl:when>
      <xsl:otherwise><xsl:attribute name="type">i</xsl:attribute></xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates/>
  </ol>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- list item -->
<xsl:template match="*[contains(@class, ' topic/li ')]" name="topic.li">
<li>
  <xsl:choose>
    <xsl:when test="parent::*/@compact = 'no'">
      <xsl:attribute name="class">liexpand</xsl:attribute>
      <!-- handle non-compact list items -->
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class" select="'liexpand'"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="commonattributes"/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:call-template name="setidaname"/>
  <xsl:apply-templates/>
</li><xsl:value-of select="$newline"/>
</xsl:template>
<!-- simple list item -->
<xsl:template match="*[contains(@class, ' topic/sli ')]" name="topic.sli">
  <li>
    <xsl:choose>
      <xsl:when test="parent::*/@compact = 'no'">
        <xsl:attribute name="class">sliexpand</xsl:attribute>
        <!-- handle non-compact list items -->
        <xsl:call-template name="commonattributes">
          <xsl:with-param name="default-output-class" select="'sliexpand'"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="commonattributes"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
  </li><xsl:value-of select="$newline"/>
</xsl:template>

<!-- special case of getting the number of a list item referenced by xref -->
<xsl:template match="*[contains(@class, ' topic/li ')]" mode="xref">
  <xsl:number/>
</xsl:template>


<!-- list item section is like li/lq but without presentation (indent) -->
<xsl:template match="*[contains(@class, ' topic/itemgroup ')]" name="topic.itemgroup">
  <!-- insert a space before all but the first itemgroups in a LI -->
  <xsl:if test="exists(preceding-sibling::*[contains(@class, ' topic/itemgroup ')])">
    <xsl:text> </xsl:text>
  </xsl:if>
  <!-- DITA-OT 1.6 and earlier created a span/font tag when active revs; otherwise, no wrapper.
       Maintain that for now, though may want to update in the future to keep a wrapper in all cases.
       Considering using div instead of span, with a default inline CSS style. -->
  <xsl:choose>
    <xsl:when test="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/revprop |
                    *[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass">
      <span>
        <xsl:call-template name="commonattributes"/>
        <xsl:apply-templates/>
      </span>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- =========== DEFINITION LIST =========== -->

<!-- DL -->
  <xsl:template match="*[contains(@class,' topic/dl ')][empty(*[contains(@class,' topic/dlentry ')])]" priority="10"/>
  
<xsl:template match="*[contains(@class, ' topic/dl ')]" name="topic.dl">
  <xsl:call-template name="setaname"/>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <dl>
    <!-- handle DL compacting - default=yes -->
    <xsl:if test="@compact = 'no'">
      <xsl:attribute name="class">dlexpand</xsl:attribute>
    </xsl:if>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="@compact"/>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates/>
  </dl>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- DL entry -->
<xsl:template match="*[contains(@class, ' topic/dlentry ')]" name="topic.dlentry">
  <xsl:apply-templates/>
</xsl:template>

<!-- SF Patch 2185423: condensed code so that dt processing is not repeated for keyref or when $dtcount!=1
     Code could be reduced further by compressing the flagging templates. -->
<xsl:template match="*[contains(@class, ' topic/dt ')]" mode="output-dt">
  <xsl:variable name="is-first-dt" select="empty(preceding-sibling::*[contains(@class, ' topic/dt ')])"/>
  <xsl:variable name="dt-class">
    <xsl:choose>
      <!-- handle non-compact list items -->
      <xsl:when test="$is-first-dt and ../../@compact = 'no'">dltermexpand</xsl:when>
      <xsl:otherwise>dlterm</xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <dt>
    <!-- Get xml:lang and ditaval styling from DLENTRY, then override with local -->
    <xsl:apply-templates select="../@xml:lang"/> 
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:for-each select="..">
      <xsl:call-template name="commonattributes"/>
    </xsl:for-each>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="$dt-class"/>
    </xsl:call-template>
    <!-- handle ID on a DLENTRY -->
    <xsl:choose>
      <xsl:when test="$is-first-dt and exists(../@id) and exists(@id)">
        <xsl:call-template name="setidaname"/>
        <a id="{dita-ot:get-prefixed-id(.., ../@id)}"/> 
      </xsl:when>
      <xsl:when test="$is-first-dt and exists(../@id) and empty(@id)">
        <xsl:for-each select="..">
          <xsl:call-template name="setidaname"/>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="setidaname"/>        
      </xsl:otherwise>
    </xsl:choose>
    <!-- Use flags from parent dlentry, if present -->
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </dt>
</xsl:template>

<!-- DL term -->
<xsl:template match="*[contains(@class, ' topic/dt ')]" name="topic.dt">
  <xsl:choose>
    <xsl:when test="@keyref and @href">
      <a>
        <xsl:apply-templates select="." mode="add-linking-attributes"/>
        <xsl:apply-templates select="." mode="output-dt"/>
      </a>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="output-dt"/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- DL description -->
<xsl:template match="*[contains(@class, ' topic/dd ')]" name="topic.dd">
  <xsl:variable name="is-first-dd" select="empty(preceding-sibling::*[contains(@class, ' topic/dd ')])"/>
  <dd>
    <xsl:for-each select="..">
      <xsl:call-template name="commonattributes"/>
    </xsl:for-each>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class">
        <xsl:if test="not($is-first-dd)">  <!-- para space before 2 thru N -->
          <xsl:text>ddexpand</xsl:text>
        </xsl:if>    
      </xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </dd>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- DL heading -->
<xsl:template match="*[contains(@class, ' topic/dlhead ')]" name="topic.dlhead">
 <xsl:apply-templates/>
</xsl:template>

<!-- DL heading, term -->
<xsl:template match="*[contains(@class, ' topic/dthd ')]" name="topic.dthd">
  <dt>
    <!-- Get ditaval style and xml:lang from DLHEAD, then override with local -->
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:apply-templates select="../@xml:lang"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <strong>
      <xsl:apply-templates/>
    </strong>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </dt><xsl:value-of select="$newline"/>
</xsl:template>

<!-- DL heading, description -->
<xsl:template match="*[contains(@class, ' topic/ddhd ')]" name="topic.ddhd">
  <dd>
    <!-- Get ditaval style and xml:lang from DLHEAD, then override with local -->
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <xsl:apply-templates select="../@xml:lang"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <strong>
      <xsl:apply-templates/>
    </strong>
    <xsl:apply-templates select="../*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </dd><xsl:value-of select="$newline"/>
</xsl:template>


<!-- =========== PHRASES =========== -->

<!-- phrase presentational style - have to use a low priority otherwise topic/ph always wins -->
<!-- should not need priority, default is low enough -->

<xsl:template match="*[contains(@class, ' topic/ph ')]" name="topic.ph">
  <xsl:choose>
    <xsl:when test="@keyref and @href">
      <xsl:apply-templates select="." mode="turning-to-link">
        <xsl:with-param name="type" select="'ph'"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <span>
        <xsl:call-template name="commonattributes"/>
        <xsl:call-template name="setidaname"/> 
        <xsl:apply-templates/>  
      </span>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
  
<!-- keyword presentational style - have to use priority else topic/keyword always wins -->
<!-- should not need priority, default is low enough -->

<xsl:template match="*[contains(@class, ' topic/keyword ')]" name="topic.keyword">
  <xsl:choose>
    <xsl:when test="@keyref and @href">
      <xsl:apply-templates select="." mode="turning-to-link">
        <xsl:with-param name="type" select="'keyword'"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <span class="keyword">
        <xsl:call-template name="commonattributes"/>
        <xsl:call-template name="setidaname"/>   
        <xsl:apply-templates/>  
      </span>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- trademarks  -->
<!-- prepare a key for each trademark tag -->
<xsl:key name="tm"  match="*[contains(@class, ' topic/tm ')]" use="."/>

<!-- process the TM tag -->
<!-- removed priority 1 : should not be needed -->
<xsl:template match="*[contains(@class, ' topic/tm ')]" name="topic.tm">

  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <xsl:apply-templates/> <!-- output the TM content -->

    <!-- Test for TM area's language -->
    <xsl:variable name="tmtest">
      <xsl:call-template name="tm-area"/>
    </xsl:variable>

    <!-- If this language should get trademark markers, continue... -->
    <xsl:if test="$tmtest = 'tm'">
      <xsl:variable name="tmvalue" select="@trademark"/>

      <!-- Determine if this is in a title, and should be marked -->
      <!-- TODO: should return boolean -->
      <xsl:variable name="usetitle">
        <xsl:if test="ancestor::*[contains(@class, ' topic/title ')]/parent::*[contains(@class, ' topic/topic ')]">
          <xsl:choose>
            <!-- Not the first one in a title -->
            <xsl:when test="generate-id(.) != generate-id(key('tm', .)[1])">skip</xsl:when>
            <!-- First one in the topic, BUT it appears in a shortdesc or body -->
            <xsl:when test="//*[contains(@class, ' topic/shortdesc ') or contains(@class, ' topic/body ')]//*[contains(@class, ' topic/tm ')][@trademark = $tmvalue]">skip</xsl:when>
            <xsl:otherwise>use</xsl:otherwise>
          </xsl:choose>
        </xsl:if>
      </xsl:variable>

      <!-- Determine if this is in a body, and should be marked -->
      <!-- TODO: should return boolean -->
      <xsl:variable name="usebody">
        <xsl:choose>
          <!-- If in a title or prolog, skip -->
          <xsl:when test="ancestor::*[contains(@class, ' topic/title ') or contains(@class, ' topic/prolog ')]/parent::*[contains(@class, ' topic/topic ')]">skip</xsl:when>
          <!-- If first in the document, use it -->
          <xsl:when test="generate-id(.) = generate-id(key('tm', .)[1])">use</xsl:when>
          <!-- If there is another before this that is in the body or shortdesc, skip -->
          <xsl:when test="preceding::*[contains(@class, ' topic/tm ')][@trademark = $tmvalue][ancestor::*[contains(@class, ' topic/body ') or contains(@class, ' topic/shortdesc ')]]">skip</xsl:when>
          <!-- Otherwise, any before this must be in a title or ignored section -->
          <xsl:otherwise>use</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <!-- If it should be used in a title or used in the body, output your favorite TM marker based on the attributes -->
      <xsl:if test="$usetitle = 'use' or $usebody = 'use'">
        <xsl:choose>  <!-- ignore @tmtype=service or anything else -->
          <xsl:when test="@tmtype = 'tm'">&#x2122;</xsl:when>
          <xsl:when test="@tmtype = 'reg'">&#174;</xsl:when>
          <xsl:when test="@tmtype = 'service'">&#8480;</xsl:when>
          <xsl:otherwise/>
        </xsl:choose>
      </xsl:if>
    </xsl:if>
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
</xsl:template>

<!-- Deprecated since 2.3 --> 
<xsl:template name="tm-area">
  <xsl:apply-templates select="." mode="mark-tm-in-this-area"/>
</xsl:template>
<!-- TODO: this should return boolean, not "tm" or something else -->
<xsl:template match="*" mode="mark-tm-in-this-area" as="xs:string">
 <xsl:text>tm</xsl:text>
</xsl:template>


<!-- phrase "semantic" classes -->
<!-- citations -->
<xsl:template match="*[contains(@class, ' topic/cite ')]" name="topic.cite">
  <xsl:choose>
    <xsl:when test="@keyref and @href">
      <xsl:apply-templates select="." mode="turning-to-link">
        <xsl:with-param name="type" select="'cite'"/>
      </xsl:apply-templates>
    </xsl:when>
    <xsl:otherwise>
      <cite>
        <xsl:call-template name="commonattributes"/>
        <xsl:call-template name="setidaname"/>
        <xsl:apply-templates/>
      </cite>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- quotes - only do 1 level, no flip-flopping -->
<xsl:template match="*[contains(@class, ' topic/q ')]" name="topic.q">
  <q>
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates/>
  </q>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/term ')]" mode="output-term">
  <!-- Deprecated since 2.1 -->
  <xsl:param name="displaytext"/>
  
  <dfn class="term">
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <xsl:choose>
      <xsl:when test="normalize-space($displaytext)">
        <xsl:value-of select="$displaytext"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </dfn>
</xsl:template>

<!-- Templates for internal usage in terms/abbreviation resolving -->
<xsl:template name="getMatchingTarget" as="element()?">
  <xsl:param name="m_glossid" select="''" as="xs:string"/>
  <xsl:param name="m_entry-file-contents" as="node()?"/>
  <xsl:param name="m_reflang" select="'en-US'" as="xs:string"/>
  <xsl:variable name="glossentries" select="$m_entry-file-contents/descendant-or-self::*[contains(@class, ' glossentry/glossentry ')]" as="element()*"/>
  <xsl:choose>
    <xsl:when test="$m_glossid = '' and $glossentries[lang($m_reflang)]">
      <xsl:sequence select="$glossentries[lang($m_reflang)][1]"/>
    </xsl:when>
    <xsl:when test="not($m_glossid = '') and $glossentries[@id = $m_glossid][lang($m_reflang)]">
      <xsl:sequence select="$glossentries[@id = $m_glossid][lang($m_reflang)]"/>
    </xsl:when>
    <xsl:when test="$m_glossid = '' and $glossentries[lang($DEFAULTLANG)]">
      <xsl:sequence select="$glossentries[lang($DEFAULTLANG)][1]"/>
    </xsl:when>
    <xsl:when test="not($m_glossid = '') and $glossentries[@id = $m_glossid][lang($DEFAULTLANG)]">
      <xsl:sequence select="$glossentries[@id = $m_glossid][lang($DEFAULTLANG)]"/>
    </xsl:when>
    <xsl:when test="$m_glossid = '' and $glossentries[not(@xml:lang) or normalize-space(@xml:lang) = '']">
      <xsl:sequence select="$glossentries[not(@xml:lang) or normalize-space(@xml:lang) = ''][1]"/>
    </xsl:when>
    <xsl:when test="not($m_glossid = '') and $glossentries[@id = $m_glossid][not(@xml:lang) or normalize-space(@xml:lang) = '']">
      <xsl:sequence select="$glossentries[@id = $m_glossid][not(@xml:lang) or normalize-space(@xml:lang) = ''][1]"/>
    </xsl:when>
    <!--xsl:otherwise>
      <xsl:value-of select="'#none#'"/>
    </xsl:otherwise-->
  </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="getMatchingSurfaceForm">
  <xsl:param name="m_matched-target" as="element()?"/>
  <xsl:param name="m_keys"/>
  <xsl:choose>
    <xsl:when test="exists($m_matched-target)">
      <xsl:variable name="glossentry" select="$m_matched-target"/>
      <xsl:choose>
        <xsl:when test="$glossentry//*[contains(@class, ' glossentry/glossSurfaceForm ')][normalize-space(.) != '']">
          <xsl:apply-templates select="$glossentry//*[contains(@class, ' glossentry/glossSurfaceForm ')][normalize-space(.) != '']" mode="dita-ot:text-only"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="$glossentry//*[contains(@class, ' glossentry/glossterm ')]" mode="dita-ot:text-only"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="ditamsg:no-glossentry-for-key">
        <xsl:with-param name="matching-keys" select="$m_keys"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="getMatchingGlossdef">
  <xsl:param name="m_matched-target" as="element()?"/>
  <xsl:param name="m_keys"/>
  <xsl:choose>
    <xsl:when test="exists($m_matched-target)">
      <xsl:variable name="glossentry" select="$m_matched-target" as="element()?"/>
      <xsl:choose>
        <xsl:when test="$glossentry/*[contains(@class, ' glossentry/glossdef ')]">
          <xsl:apply-templates select="$glossentry/*[contains(@class, ' glossentry/glossdef ')]" mode="dita-ot:text-only"/>
        </xsl:when>
        <xsl:when test="$glossentry//*[contains(@class, ' glossentry/glossSurfaceForm ')][normalize-space(.) != '']">
          <!-- Second choice: surface form, as it may contain *slightly* more information than the original term -->
          <xsl:apply-templates select="$glossentry//*[contains(@class, ' glossentry/glossSurfaceForm ')][normalize-space(.) != '']" mode="dita-ot:text-only"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- Fall back to term if there is no definition and no surface form -->
          <xsl:apply-templates select="$glossentry//*[contains(@class, ' glossentry/glossterm ')]" mode="dita-ot:text-only"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:when test="normalize-space(.) = '' and
                    (boolean(ancestor::*[contains(@class, ' topic/copyright ')]) or generate-id(.) = generate-id(key('keyref', @keyref)[1]))">
      <!-- Already generating a message when looking for the term, do not generate a "missing glossentry" message here too -->
    </xsl:when>
    <xsl:when test="boolean(ancestor::*[contains(@class, ' topic/copyright ')]) or generate-id(.) = generate-id(key('keyref', @keyref)[1])">
      <!-- Didn't look up term because it was specified, but this is the first occurrence
           and the glossentry was not found, so generate "missing glossentry" message -->
      <xsl:apply-templates select="." mode="ditamsg:no-glossentry-for-key">
        <xsl:with-param name="matching-keys" select="$m_keys"/>
      </xsl:apply-templates>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="*" mode="getMatchingAcronym">
  <xsl:param name="m_matched-target" as="element()?"/>
  <xsl:param name="m_keys"/>
  <xsl:choose>
    <xsl:when test="exists($m_matched-target)">
      <xsl:variable name="glossentry" select="$m_matched-target"/>
      <xsl:choose>
        <xsl:when test="$glossentry//*[contains(@class, ' glossentry/glossStatus ')][@value = 'preferred'][1]/preceding-sibling::*[contains(@class, ' glossentry/glossAcronym ') or contains(@class, ' glossentry/glossAbbreviation ')][normalize-space(.) != '']">
          <xsl:apply-templates select="$glossentry//*[contains(@class, ' glossentry/glossStatus ')][@value = 'preferred'][1]/preceding-sibling::*[contains(@class, ' glossentry/glossAcronym ') or contains(@class, ' glossentry/glossAbbreviation ')][normalize-space(.) != '']" mode="dita-ot:text-only"/>
        </xsl:when>
        <xsl:when test="$glossentry//*[contains(@class, ' glossentry/glossStatus ')][@value != 'prohibited' and @value != 'obsolete'][1]/preceding-sibling::*[contains(@class, ' glossentry/glossAcronym ') or contains(@class, ' glossentry/glossAbbreviation ')][normalize-space(.) != '']">
          <xsl:apply-templates select="$glossentry//*[contains(@class, ' glossentry/glossStatus ')][@value != 'prohibited' and @value != 'obsolete'][1]/preceding-sibling::*[contains(@class, ' glossentry/glossAcronym ') or contains(@class, ' glossentry/glossAbbreviation ')][normalize-space(.) != '']" mode="dita-ot:text-only"/>
        </xsl:when>
        <xsl:when test="$glossentry//*[contains(@class, ' glossentry/glossAlt ')][1]/*[contains(@class, ' glossentry/glossAcronym ') or contains(@class, ' glossentry/glossAbbreviation ')][not(following-sibling::glossStatus)][normalize-space(.) != '']">
          <xsl:apply-templates select="$glossentry//*[contains(@class, ' glossentry/glossAlt ')][1]/*[contains(@class, ' glossentry/glossAcronym ') or contains(@class, ' glossentry/glossAbbreviation ')][count(following-sibling::glossStatus) = 0][normalize-space(.) != '']" mode="dita-ot:text-only"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="$glossentry/*[contains(@class, ' glossentry/glossterm ')]" mode="dita-ot:text-only"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <!-- No matching entries found with reference language or default language. -->
      <xsl:apply-templates select="." mode="ditamsg:no-glossentry-for-key">
        <xsl:with-param name="matching-keys" select="$m_keys"/>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Note: processing for the term specialization abbreviated-form is located in abbrev-d.xsl. -->
<xsl:key name="keyref" match="*[contains(@class, ' topic/term ')]" use="@keyref"/>
<!-- terms and abbreviated-forms -->
<xsl:template match="*[contains(@class, ' topic/term ')]" name="topic.term">
  <xsl:variable name="keys" select="@keyref" as="attribute()?"/>
  <xsl:choose>
    <xsl:when test="@keyref and @href">
      <xsl:variable name="updatedTarget" as="xs:string">
        <xsl:apply-templates select="." mode="find-keyref-target"/>
      </xsl:variable>
      
      <xsl:variable name="entry-file-contents" as="node()?">
        <xsl:if test="empty(@scope) or @scope = 'local'">
          <xsl:sequence select="dita-ot:retrieve-href-target(@href)"/>
        </xsl:if>
      </xsl:variable>
      <!-- Glossary id defined in <glossentry> -->
      <xsl:variable name="glossid" select="substring-after($updatedTarget, '#')" as="xs:string"/>
      <!--
          Language preference.
          NOTE: glossid overrides language preference.
      -->
      <xsl:variable name="reflang" as="xs:string?">
        <xsl:call-template name="getLowerCaseLang"/>
      </xsl:variable>
      <xsl:variable name="matched-target" as="element()?">
        <xsl:call-template name="getMatchingTarget">
          <xsl:with-param name="m_entry-file-contents" select="$entry-file-contents"/>
          <xsl:with-param name="m_glossid" select="$glossid"/>
          <xsl:with-param name="m_reflang" select="$reflang"/>
        </xsl:call-template>
      </xsl:variable>
      <!-- End: Language preference. -->

      <!-- Text should be displayed -->
      <xsl:variable name="displaytext">
        <xsl:choose>
          <xsl:when test="normalize-space(.) != '' and empty(processing-instruction('ditaot')[. = 'gentext'])">
            <xsl:apply-templates mode="dita-ot:text-only"/>
          </xsl:when>
          <xsl:when test="exists(ancestor::*[contains(@class, ' topic/copyright ')]) or generate-id(.) = generate-id(key('keyref', @keyref)[1])">
            <xsl:apply-templates select="." mode="getMatchingSurfaceForm">
              <xsl:with-param name="m_matched-target" select="$matched-target"/>
              <xsl:with-param name="m_keys" select="$keys"/>
            </xsl:apply-templates>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="getMatchingAcronym">
              <xsl:with-param name="m_matched-target" select="$matched-target"/>
              <xsl:with-param name="m_keys" select="$keys"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- End of displaytext -->

      <!-- hovertip text -->
      <xsl:variable name="hovertext">
        <xsl:apply-templates select="." mode="getMatchingGlossdef">
          <xsl:with-param name="m_matched-target" select="$matched-target"/>
          <xsl:with-param name="m_keys" select="$keys"/>
        </xsl:apply-templates>
      </xsl:variable>
      <!-- End of hovertip text -->

      <a>
        <xsl:apply-templates select="." mode="add-linking-attributes"/>
        <xsl:apply-templates select="." mode="add-desc-as-hoverhelp">
          <xsl:with-param name="hovertext" select="$hovertext">
          </xsl:with-param>
        </xsl:apply-templates>
        <xsl:apply-templates select="." mode="output-term">
          <xsl:with-param name="displaytext" select="normalize-space($displaytext)"/>
        </xsl:apply-templates>
      </a>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="output-term">
        <xsl:with-param name="displaytext">
          <xsl:apply-templates select="."  mode="dita-ot:text-only"/>
        </xsl:with-param>
      </xsl:apply-templates>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- =========== BOOLEAN-STATE DATA TYPES =========== -->
<!-- Use color to indicate these types for now -->
<!-- output the tag & it's state -->
<xsl:template match="*[contains(@class, ' topic/boolean ')]" name="topic.boolean">
 <span style="color:green">
  <xsl:call-template name="commonattributes"/>
  <xsl:call-template name="setidaname"/>
  <xsl:value-of select="name()"/><xsl:text>: </xsl:text><xsl:value-of select="@state"/>
 </span>
</xsl:template>

<!-- output the tag, it's name & value -->
<xsl:template match="*[contains(@class, ' topic/state ')]" name="topic.state">
<span style="color:red">
  <xsl:call-template name="commonattributes"/>
  <xsl:call-template name="setidaname"/>
  <xsl:value-of select="name()"/><xsl:text>: </xsl:text><xsl:value-of select="@name"/><xsl:text>=</xsl:text><xsl:value-of select="@value"/>
</span>
</xsl:template>


<!-- =========== RECORD END RESPECTING DATA =========== -->
<!-- PRE -->
<xsl:template match="*[contains(@class, ' topic/pre ')]" name="topic.pre">
  <xsl:if test="contains(@frame, 'top')"><hr /></xsl:if>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <xsl:call-template name="spec-title-nospace"/>
  <pre>
    <xsl:attribute name="class" select="name()"/>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setscale"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
  </pre>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  <xsl:if test="contains(@frame, 'bot')"><hr /></xsl:if><xsl:value-of select="$newline"/>
</xsl:template>

<!-- lines - body font -->
<xsl:template match="*[contains(@class, ' topic/lines ')]" name="topic.lines">
  <xsl:if test="contains(@frame, 'top')"><hr /></xsl:if>
  <xsl:call-template name="spec-title-nospace"/>
  <p>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setscale"/>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
  </p>
  <xsl:if test="contains(@frame, 'bot')"><hr /></xsl:if><xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/lines ')]//text()">
 <xsl:variable name="linetext" select="."/>
 <xsl:variable name="linetext2">
  <xsl:call-template name="sp-replace"><xsl:with-param name="sptext" select="$linetext"/></xsl:call-template>
 </xsl:variable>
 <xsl:call-template name="br-replace">
  <xsl:with-param name="brtext" select="$linetext2"/>
 </xsl:call-template>
</xsl:template>


<!-- =========== FIGURE =========== -->
<xsl:template match="*[contains(@class, ' topic/fig ')]" name="topic.fig">
  <xsl:variable name="default-fig-class">
    <xsl:apply-templates select="." mode="dita2html:get-default-fig-class"/>
  </xsl:variable>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <figure>
    <xsl:if test="$default-fig-class != ''">
      <xsl:attribute name="class" select="$default-fig-class"/>
    </xsl:if>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="$default-fig-class"/>
    </xsl:call-template>
    <xsl:call-template name="setscale"/>
    <xsl:call-template name="setidaname"/>
    <xsl:call-template name="place-fig-lbl"/>
    <xsl:apply-templates select="node() except *[contains(@class, ' topic/title ') or contains(@class, ' topic/desc ')]"/>
  </figure>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- Determine the default XHTML class attribute for a figure -->
<xsl:template match="*" mode="dita2html:get-default-fig-class">
  <xsl:choose>
    <xsl:when test="@frame = 'all'">figborder</xsl:when>
    <xsl:when test="@frame = 'sides'">figsides</xsl:when>
    <xsl:when test="@frame = 'top'">figtop</xsl:when>
    <xsl:when test="@frame = 'bottom'">figbottom</xsl:when>
    <xsl:when test="@frame = 'topbot'">figtopbot</xsl:when>
    <xsl:otherwise>fignone</xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- should not need priority, default is low enough; was set to 1 -->
<xsl:template match="*[contains(@class, ' topic/figgroup ')]" name="topic.figgroup">
  <!-- Figgroup can contain blocks, maybe this should be a div?
       Changing to <div> with DITA-OT 2.3 -->
  <div>
    <xsl:call-template name="commonattributes"/>
    <xsl:call-template name="setidaname"/>
    <!-- Allow title to fallthrough -->
    <xsl:apply-templates/>
  </div>
</xsl:template>


<!-- =========== IMAGE/OBJECT =========== -->

<xsl:template match="*[contains(@class, ' topic/image ')]" name="topic.image">
  <!-- build any pre break indicated by style -->
  <xsl:choose>
    <xsl:when test="parent::*[contains(@class, ' topic/fig ')][contains(@frame, 'top ')]">
      <!-- NOP if there is already a break implied by a parent property -->
    </xsl:when>
    <xsl:when test="@placement = 'break'">
      <br/>
    </xsl:when>
  </xsl:choose>
  <xsl:call-template name="setaname"/>
  <xsl:choose>
    <xsl:when test="@placement = 'break'"><!--Align only works for break-->
      <xsl:choose>
        <xsl:when test="@align = 'left'">
          <div class="imageleft">
            <xsl:call-template name="topic-image"/>
          </div>
        </xsl:when>
        <xsl:when test="@align = 'right'">
          <div class="imageright">
            <xsl:call-template name="topic-image"/>
          </div>
        </xsl:when>
        <xsl:when test="@align = 'center'">
          <div class="imagecenter">
            <xsl:call-template name="topic-image"/>
          </div>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="topic-image"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="topic-image"/>
    </xsl:otherwise>
  </xsl:choose>
  <!-- build any post break indicated by style -->
  <xsl:if test="not(@placement = 'inline')"><br/></xsl:if>
  <!-- image name for review -->
  <xsl:if test="$ARTLBL = 'yes'"> [<xsl:value-of select="@href"/>] </xsl:if>
</xsl:template>

<xsl:template name="topic-image">
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
  <img>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class">
        <xsl:if test="@placement = 'break'"><!--Align only works for break-->
          <xsl:choose>
            <xsl:when test="@align = 'left'">imageleft</xsl:when>
            <xsl:when test="@align = 'right'">imageright</xsl:when>
            <xsl:when test="@align = 'center'">imagecenter</xsl:when>
          </xsl:choose>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="setid"/>
    <xsl:choose>
      <xsl:when test="*[contains(@class, ' topic/longdescref ')]">
        <xsl:apply-templates select="*[contains(@class, ' topic/longdescref ')]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="@longdescref"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="@href|@height|@width"/>
    <xsl:apply-templates select="@scale"/>
    <xsl:choose>
      <xsl:when test="*[contains(@class, ' topic/alt ')]">
        <xsl:variable name="alt-content"><xsl:apply-templates select="*[contains(@class, ' topic/alt ')]" mode="text-only"/></xsl:variable>
        <xsl:attribute name="alt" select="normalize-space($alt-content)"/>
      </xsl:when>
      <xsl:when test="@alt">
        <xsl:attribute name="alt" select="@alt"/>
      </xsl:when>
    </xsl:choose>
  </img>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/alt ')]">
  <xsl:apply-templates select="." mode="text-only"/>
</xsl:template>

<!-- Process image attributes. Using priority, in case default @href is added at some point. -->
<!-- 20090303: Removed priority; does not appear to be needed. -->
<xsl:template match="*[contains(@class, ' topic/image ')]/@href">
  <xsl:attribute name="src" select="."/>
</xsl:template>

<!-- AM: handling for scale attribute -->
<xsl:template match="*[contains(@class, ' topic/image ')]/@scale">
    <xsl:variable name="width" select="../@dita-ot:image-width"/>
    <xsl:variable name="height" select="../@dita-ot:image-height"/>
    <xsl:if test="not(../@width) and not(../@height)">
      <xsl:attribute name="height" select="floor(number($height) * number(.) div 100)"/>
      <xsl:attribute name="width" select="floor(number($width) * number(.) div 100)"/>
    </xsl:if>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/image ')]/@height">
  <xsl:variable name="height-in-pixel">
    <xsl:call-template name="length-to-pixels">
      <xsl:with-param name="dimen" select="."/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:if test="not($height-in-pixel = '100%')">
    <xsl:attribute name="height">
      <!--xsl:choose>
        <xsl:when test="../@scale and string(number(../@scale))!='NaN'">          
          <xsl:value-of select="number($height-in-pixel) * number(../@scale)"/>
        </xsl:when>
        <xsl:otherwise-->
          <xsl:value-of select="number($height-in-pixel)"/>
        <!--/xsl:otherwise>
      </xsl:choose-->
    </xsl:attribute>
  </xsl:if>  
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/image ')]/@width">
  <xsl:variable name="width-in-pixel">
    <xsl:call-template name="length-to-pixels">
      <xsl:with-param name="dimen" select="."/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:if test="not($width-in-pixel = '100%')">
    <xsl:attribute name="width">
      <!--xsl:choose>
        <xsl:when test="../@scale and string(number(../@scale))!='NaN'">          
          <xsl:value-of select="number($width-in-pixel) * number(../@scale)"/>
        </xsl:when>
        <xsl:otherwise-->
          <xsl:value-of select="number($width-in-pixel)"/>
        <!--/xsl:otherwise>
      </xsl:choose-->
    </xsl:attribute>
  </xsl:if>  
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/image ')]/@longdescref">
  <xsl:attribute name="longdesc">
    <xsl:choose>
      <!-- Guess whether link target is a DITA topic or something else -->
      <xsl:when test="contains(., '.dita') or contains(., '.xml')">
        <xsl:call-template name="replace-extension">
          <xsl:with-param name="filename" select="."/>
          <xsl:with-param name="extension" select="$OUTEXT"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:template>

  <xsl:template match="*[contains(@class, ' topic/image ')]/*[contains(@class, ' topic/longdescref ')]">
  <xsl:if test="@href and not (@href = '')">
    <xsl:attribute name="longdesc">
      <xsl:choose>
        <xsl:when test="not(@format) or @format = 'dita'">
          <xsl:call-template name="replace-extension">
            <xsl:with-param name="filename" select="@href"/>
            <xsl:with-param name="extension" select="$OUTEXT"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@href"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:if>
</xsl:template>


<!-- object, desc, & param -->
<xsl:template match="*[contains(@class, ' topic/object ')]" name="topic.object">
 <object>
  <xsl:copy-of select="@id | @declare | @codebase | @type | @archive | @height | @usemap | @tabindex | @classid | @data | @codetype | @standby | @width | @name"/>
  <xsl:if test="@longdescref or *[contains(@class, ' topic/longdescref ')]">
    <xsl:apply-templates select="." mode="ditamsg:longdescref-on-object"/>
  </xsl:if>
  <xsl:apply-templates/>
 <!-- Test for Flash movie; include EMBED statement for non-IE browsers -->
 <xsl:if test="contains(@codebase, 'swflash.cab')">
  <embed>
   <xsl:if test="@id"><xsl:attribute name="name" select="@id"/></xsl:if>
   <xsl:copy-of select="@height | @width"/>
   <xsl:attribute name="type"><xsl:text>application/x-shockwave-flash</xsl:text></xsl:attribute>
   <xsl:attribute name="pluginspage"><xsl:text>http://www.macromedia.com/go/getflashplayer</xsl:text></xsl:attribute>
   <xsl:if test="*[contains(@class, ' topic/param ')]/@name = 'movie'">
    <xsl:attribute name="src" select="*[contains(@class, ' topic/param ')][@name = 'movie']/@value"/>
   </xsl:if>
   <xsl:if test="*[contains(@class, ' topic/param ')]/@name = 'quality'">
    <xsl:attribute name="quality" select="*[contains(@class, ' topic/param ')][@name = 'quality']/@value"/>
   </xsl:if>
   <xsl:if test="*[contains(@class, ' topic/param ')]/@name = 'bgcolor'">
    <xsl:attribute name="bgcolor" select="*[contains(@class, ' topic/param ')][@name = 'bgcolor']/@value"/>
   </xsl:if>
  </embed>
 </xsl:if>
 </object>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/param ')]" name="topic.param">
 <param>
  <xsl:copy-of select="@name | @id | @value"/>
 </param>
</xsl:template>

<!-- need to add test for object/desc to avoid conflicts -->
<xsl:template match="*[contains(@class, ' topic/object ')]/*[contains(@class, ' topic/desc ')]" name="topic.object_desc">
 <span>
  <xsl:copy-of select="@name | @id | value"/>
  <xsl:apply-templates/>
 </span>
</xsl:template>

<!-- ===================================================================== -->

<xsl:include href="plugin:org.dita.xhtml:xsl/xslhtml/tables.xsl"/>

<!-- =========== FOOTNOTE =========== -->
<xsl:template match="*[contains(@class, ' topic/fn ')]" name="topic.fn">
  <xsl:param name="xref"/>
  <!-- when FN has an ID, it can only be referenced, otherwise, output an a-name & a counter -->
  <xsl:if test="not(@id) or $xref = 'yes'">
    <xsl:variable name="fnid"><xsl:number from="/" level="any"/></xsl:variable>
    <xsl:variable name="callout" select="@callout"/>
    <xsl:variable name="convergedcallout" select="if (string-length($callout)> 0) then $callout else $fnid"/>
     <a name="fnsrc_{$fnid}" href="#fntarg_{$fnid}">
      <sup>
        <xsl:value-of select="$convergedcallout"/>
      </sup>
     </a>
  </xsl:if>
</xsl:template>


<!-- =========== REQUIRED CLEANUP and REVIEW COMMENT =========== -->

<xsl:template match="*[contains(@class, ' topic/required-cleanup ')]" mode="default-required-cleanup-style">
  <xsl:call-template name="style">
    <xsl:with-param name="contents">background-color: #FFFF99; color:#CC3333; border: 1pt black solid;</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/draft-comment ')]" mode="default-draft-comment-style">
  <xsl:call-template name="style">
    <xsl:with-param name="contents">background-color: #99FF99; border: 1pt black solid;</xsl:with-param>
  </xsl:call-template>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/required-cleanup ')]" name="topic.required-cleanup">
  <xsl:if test="$DRAFT = 'yes'">
    <xsl:apply-templates select="." mode="ditamsg:required-cleanup-in-content"/>
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="." mode="default-required-cleanup-style"/>
      <xsl:call-template name="setidaname"/>
      <strong><xsl:call-template name="getVariable">
         <xsl:with-param name="id" select="'Required cleanup'"/>
       </xsl:call-template>
       <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'ColonSymbol'"/>
       </xsl:call-template><xsl:text> </xsl:text></strong>
      <xsl:if test="@remap">[<xsl:value-of select="@remap"/>] </xsl:if>
      <xsl:apply-templates/>
    </div><xsl:value-of select="$newline"/>
  </xsl:if>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/draft-comment ')]" name="topic.draft-comment">
 <xsl:if test="$DRAFT = 'yes'">
   <xsl:apply-templates select="." mode="ditamsg:draft-comment-in-content"/>
   <div>
     <xsl:call-template name="commonattributes"/>
     <xsl:apply-templates select="." mode="default-draft-comment-style"/>
     <xsl:call-template name="setidaname"/>
     <strong><xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'Draft comment'"/>
      </xsl:call-template>
      <xsl:call-template name="getVariable">
        <xsl:with-param name="id" select="'ColonSymbol'"/>
       </xsl:call-template><xsl:text> </xsl:text></strong>
     <xsl:if test="@author"><xsl:value-of select="@author"/><xsl:text> </xsl:text></xsl:if>
     <xsl:if test="@disposition"><xsl:value-of select="@disposition"/><xsl:text> </xsl:text></xsl:if>
     <xsl:if test="@time"><xsl:value-of select="@time"/></xsl:if>
     <br/>
     <xsl:apply-templates/>
  </div><xsl:value-of select="$newline"/>
 </xsl:if>
</xsl:template>

<!--Dita comment passthru-->
<xsl:template match="processing-instruction()">
  <xsl:if test="name()='dita-comment'"><xsl:comment><xsl:value-of select="."/></xsl:comment></xsl:if>
</xsl:template>

<!-- =========== INDEX =========== -->

<!-- TBD: this needs practical implementation.  currently the support merely
     echoes the content back, indicating any nesting.  Useful view for authoring!-->
<xsl:template match="*[contains(@class, ' topic/indexterm ')]" name="topic.indexterm">
 <xsl:if test="$INDEXSHOW = 'yes'">
   <xsl:choose>
     <xsl:when test="@keyref and @href">
       <a>
         <xsl:apply-templates select="." mode="add-linking-attributes"/>
         <span style="margin: 1pt; background-color: #ffddff; border: 1pt black solid;">
           <xsl:call-template name="commonattributes"/>
           <xsl:apply-templates/>
         </span>
       </a>
     </xsl:when>
     <xsl:otherwise>
       <span style="margin: 1pt; background-color: #ffddff; border: 1pt black solid;">
         <xsl:call-template name="commonattributes"/>
         <xsl:apply-templates/>
       </span>
     </xsl:otherwise>
   </xsl:choose>
 </xsl:if>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/indextermref ')]"/>


<!-- ===================================================================== -->

<!-- =========== PROLOG =========== -->
<!-- all handled in get-meta.xsl -->
<xsl:template match="*[contains(@class, ' topic/prolog ')]"/>


<!-- ===================================================================== -->

<!-- ================= COMMON ATTRIBUTE PROCESSORS ====================== -->

  <xsl:function name="dita-ot:generate-id" as="xs:string">
    <xsl:param name="topic" as="xs:string?"/>
    <xsl:param name="element" as="xs:string?"/>
    
    <xsl:value-of select="string-join(($topic, $element), $HTML_ID_SEPARATOR)"/>
  </xsl:function>

<xsl:function name="dita-ot:get-prefixed-id" as="xs:string">
  <xsl:param name="element" as="element()"/>
  <xsl:param name="id" as="xs:string"/>

  <xsl:sequence select="dita-ot:generate-id($element/ancestor::*[contains(@class, ' topic/body ')][1]/parent::*/@id, $id)"/>
</xsl:function>

<xsl:function name="dita-ot:generate-html-id" as="xs:string">
  <xsl:param name="element" as="element()"/>

  <xsl:sequence
    select="if (exists($element/@id))
          then dita-ot:get-prefixed-id($element, $element/@id)
          else generate-id($element)"/>
</xsl:function>

<!-- If the element has an ID, set it as an ID and anchor-->
<!-- Set ID and output A-name -->
<xsl:template name="setidaname">
 <xsl:if test="@id">
  <xsl:call-template name="setidattr">
   <xsl:with-param name="idvalue" select="@id"/>
  </xsl:call-template>
  <xsl:call-template name="setanametag">
   <xsl:with-param name="idvalue" select="@id"/>
  </xsl:call-template>
 </xsl:if>
</xsl:template>

<!-- Set ID only -->
<xsl:template name="setid">
 <xsl:if test="@id">
  <xsl:call-template name="setidattr">
   <xsl:with-param name="idvalue" select="@id"/>
  </xsl:call-template>
 </xsl:if>
</xsl:template>

<!-- Set A-name only -->
<xsl:template name="setaname">
 <xsl:if test="@id">
  <xsl:call-template name="setanametag">
   <xsl:with-param name="idvalue" select="@id"/>
  </xsl:call-template>
 </xsl:if>
</xsl:template>

<!-- Set the ID attr for IE -->
<xsl:template name="setidattr">
  <xsl:param name="idvalue"/>
  <xsl:attribute name="id"
    select="dita-ot:get-prefixed-id($idvalue/parent::*, $idvalue)"/>
</xsl:template>

<!-- Legacy named template for generating HTML4 anchors -->
<xsl:template name="setanametag">
  <xsl:param name="idvalue"/>
</xsl:template>

<!-- Create & insert an ID for the generated table of contents -->
<xsl:template name="gen-toc-id">

</xsl:template>

<!-- Process standard attributes that may appear anywhere. Previously this was "setclass" -->
<xsl:template name="commonattributes">
  <xsl:param name="default-output-class"/>
  <xsl:apply-templates select="@xml:lang"/>
  <xsl:apply-templates select="@dir"/>
  <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
  <xsl:apply-templates select="." mode="set-output-class">
    <xsl:with-param name="default" select="$default-output-class"/>
  </xsl:apply-templates>
  <xsl:if test="exists($passthrough-attrs)">
    <xsl:for-each select="@*">
      <xsl:if test="$passthrough-attrs[@att = name(current()) and (empty(@val) or (some $v in tokenize(current(), '\s+') satisfies $v = @val))]">
        <xsl:attribute name="data-{name()}" select="."/>
      </xsl:if>
    </xsl:for-each>
  </xsl:if>
</xsl:template>

<!-- Set the class attribute on the resulting output element. The default for a class of elements
     may be passed in with $default, but that default can be overridden with mode="get-output-class". -->
<xsl:template match="*" mode="set-output-class">
  <xsl:param name="default"/>
  <xsl:variable name="output-class">
    <xsl:apply-templates select="." mode="get-output-class"/>
  </xsl:variable>
  <xsl:variable name="draft-revs">
    <!-- If draft is on, add revisions to default class. Simplifies processing in DITA-OT 1.6 and earlier
         that created an extra div or span around revised content, just to hold @class with revs. -->
    <xsl:if test="$DRAFT = 'yes'">
      <xsl:for-each select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/revprop">
        <xsl:value-of select="@val"/>
        <xsl:text> </xsl:text>
      </xsl:for-each>
    </xsl:if>
  </xsl:variable>
  <xsl:variable name="using-output-class">
    <xsl:choose>
      <xsl:when test="string-length(normalize-space($output-class)) > 0"><xsl:value-of select="$output-class"/></xsl:when>
      <xsl:when test="string-length(normalize-space($default)) > 0"><xsl:value-of select="$default"/></xsl:when>
    </xsl:choose>
    <xsl:if test="$draft-revs != ''">
      <xsl:text> </xsl:text>
      <xsl:value-of select="normalize-space($draft-revs)"/>
    </xsl:if>
  </xsl:variable>
  <xsl:variable name="ancestry">
    <xsl:if test="$PRESERVE-DITA-CLASS = 'yes'">
      <xsl:apply-templates select="." mode="get-element-ancestry"/>
    </xsl:if>
  </xsl:variable>
  <xsl:variable name="outputclass-attribute">
    <xsl:apply-templates select="@outputclass" mode="get-value-for-class"/>
  </xsl:variable>
  <!-- Revised design with DITA-OT 1.5: include class ancestry if requested; 
       combine user output class with element default, giving priority to the user value. -->
  <xsl:if test="string-length(normalize-space(concat($outputclass-attribute, $using-output-class, $ancestry))) > 0">
    <xsl:attribute name="class">
      <xsl:value-of select="$ancestry"/>
      <xsl:if test="string-length(normalize-space($ancestry)) > 0 and 
                    string-length(normalize-space($using-output-class)) > 0"><xsl:text> </xsl:text></xsl:if>
      <xsl:value-of select="normalize-space($using-output-class)"/>
      <xsl:if test="string-length(normalize-space(concat($ancestry, $using-output-class))) > 0 and
                    string-length(normalize-space($outputclass-attribute)) > 0"><xsl:text> </xsl:text></xsl:if>
      <xsl:value-of select="$outputclass-attribute"/>
    </xsl:attribute>
  </xsl:if>
</xsl:template>
  
<!-- If an element has @outputclass, create a class value -->
<xsl:template match="@outputclass">
  <xsl:attribute name="class" select="."/>
</xsl:template>
<!-- Determine what @outputclass value goes into XHTML's @class. If the value should
     NOT fall through, override this template to remove it. -->
<xsl:template match="@outputclass" mode="get-value-for-class">
  <xsl:value-of select="."/>
</xsl:template>

<!-- Most elements don't get a class attribute. -->
<xsl:template match="node() | @*" mode="get-output-class"/>
  
<!-- Get the ancestry of the current element (name only, not module) -->
<xsl:template match="*" mode="get-element-ancestry">
  <xsl:param name="checkclass" select="@class"/>
  <xsl:if test="contains($checkclass, '/')">
    <xsl:variable name="lastpair">
      <xsl:call-template name="get-last-class-pair">
        <xsl:with-param name="checkclass" select="$checkclass"/>
      </xsl:call-template>
    </xsl:variable>
    <!-- If there are any module/element pairs before the last one, process them and add a space -->
    <xsl:if test="contains(substring-before($checkclass, $lastpair), '/')">
      <xsl:apply-templates select="." mode="get-element-ancestry">
        <xsl:with-param name="checkclass" select="substring-before($checkclass, $lastpair)"/>
      </xsl:apply-templates>
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:value-of select="substring-after($lastpair, '/')"/>
  </xsl:if>
</xsl:template>

<!-- Find the last module/element pair in a class string -->
<xsl:template name="get-last-class-pair">
  <xsl:param name="checkclass" select="@class"/>
  <xsl:choose>
    <xsl:when test="contains(substring-after($checkclass, ' '), '/')">
      <xsl:call-template name="get-last-class-pair">
        <xsl:with-param name="checkclass" select="substring-after($checkclass, ' ')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="contains($checkclass, '/')">
      <xsl:value-of select="normalize-space($checkclass)"/>
    </xsl:when>
    <xsl:otherwise><!-- Error condition --></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- If an element has @xml:lang, copy it to the output -->
<xsl:template match="@xml:lang" name="generate-lang">
  <xsl:param name="lang" select="."/>
  <xsl:attribute name="lang" select="$lang"/>
</xsl:template>

<!-- If an element has @dir, copy it to the output -->
<xsl:template match="@dir">
  <xsl:attribute name="dir" select="."/>
</xsl:template>

<!-- if the element has a compact=yes attribute, assert it in XHTML form -->
<xsl:template match="@compact">
  <xsl:if test=". = 'yes'">
   <xsl:attribute name="compact">compact</xsl:attribute><!-- assumes that no compaction is default -->
  </xsl:if>
</xsl:template>

<xsl:template name="setscale">
  <xsl:if test="@scale">
<!--    <xsl:attribute name="style">font-size: <xsl:value-of select="@scale"/>%;</xsl:attribute> -->
  </xsl:if>
</xsl:template>

  <xsl:template name="style">
    <xsl:param name="contents"/>
    <xsl:if test="normalize-space($contents)">
      <xsl:attribute name="style" select="$contents"/>
    </xsl:if>
  </xsl:template>


<!-- ===================================================================== -->
<!-- ========== GENERAL SUPPORT/DOC CONTENT MANAGEMENT          ========== -->
<!-- ===================================================================== -->

<!-- =========== CATCH UNDEFINED ELEMENTS (for stylesheet maintainers) =========== -->

<!-- (this rule should NOT produce output in production setting) -->
<xsl:template match="*" name="topic.undefined_element">
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX074W'"/>
    <xsl:with-param name="msgparams">%1=<xsl:value-of select="@class"/></xsl:with-param>
  </xsl:call-template>
  <span class="undefined_element">
    <xsl:apply-templates/>
  </span>
</xsl:template>

<!-- ========= NAMED TEMPLATES (call by name, only) ========== -->
<!-- named templates that can be used anywhere -->

<!-- Process spectitle attribute - if one exists - needs to be called on tags that allow it -->
<xsl:template name="spec-title">
 <xsl:if test="@spectitle"><div style="margin-top: 1em;"><strong><xsl:value-of select="@spectitle"/></strong></div></xsl:if>
</xsl:template>
<xsl:template name="spec-title-nospace">
 <xsl:if test="@spectitle"><div style="margin-bottom: 0;"><strong><xsl:value-of select="@spectitle"/></strong></div></xsl:if>
</xsl:template>

<xsl:template name="spec-title-cell">  <!-- not used - was a cell 'title' -->
 <xsl:if test="@specentry"><xsl:value-of select="@specentry"/><xsl:text> </xsl:text></xsl:if>
</xsl:template>


<xsl:template name="copyright">

</xsl:template>

<!-- Break replace - used for LINES -->
<!-- this replaces newlines with the BR element. Forces breaks. -->
<xsl:template name="br-replace">
  <xsl:param name="brtext"/>
<!-- capture an actual newline within the xsl:text element -->
  <xsl:variable name="cr"><xsl:text>
</xsl:text></xsl:variable>
  <xsl:choose>
    <xsl:when test="contains($brtext, $cr)"> 
       <xsl:value-of select="substring-before($brtext, $cr)"/>
<br/><xsl:value-of select="$cr"/>
       <xsl:call-template name="br-replace"> <!-- call again to get remaining CRs -->
         <xsl:with-param name="brtext" select="substring-after($brtext, $cr)"/>
       </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$brtext"/> <!-- No CRs, just output -->
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Space replace - used for LINES -->
<!-- add checks for repeating leading blanks & converts them to &nbsp;&nbsp; -->
<!-- this replaces newlines with the BR element. Forces breaks. -->
<xsl:template name="sp-replace">
  <xsl:param name="sptext"/>
<!-- capture 2 spaces -->
  <xsl:choose>
    <xsl:when test="contains($sptext, '  ')">
       <xsl:value-of select="substring-before($sptext, '  ')"/>
       <xsl:text>&#xA0;&#xA0;</xsl:text>
       <xsl:call-template name="sp-replace"> <!-- call again to get remaining spaces -->
         <xsl:with-param name="sptext" select="substring-after($sptext, '  ')"/>
       </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$sptext"/> <!-- No spaces, just output -->
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- diagnostic: call this to generate a path-like view of an element's ancestry -->
<xsl:template name="breadcrumbs">
<xsl:variable name="full-path">
  <xsl:for-each select="ancestor-or-self::*">
    <xsl:value-of select="concat('/', name())"/>
  </xsl:for-each>
</xsl:variable>
<p><strong><xsl:value-of select="$full-path"/></strong></p>
</xsl:template>


<!-- the following named templates generate inline content for the delivery context -->

<!-- named templates for labels and titles related to topic structures -->

<!-- test processors for HTML title element -->
<xsl:template match="*|text()|processing-instruction()" mode="text-only">
  <!-- Redirect to common dita-ot module -->
  <xsl:apply-templates select="." mode="dita-ot:text-only"/>
</xsl:template>

<!-- Process a section heading - H4 based on: 1) title element 2) @spectitle attr -->
<xsl:template name="sect-heading">
  <xsl:param name="defaulttitle"/> <!-- get param by reference -->
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX066W'"/>
    <xsl:with-param name="msgparams">%1=sect-heading</xsl:with-param>
  </xsl:call-template>
  <xsl:apply-templates select="." mode="dita2html:section-heading">
    <xsl:with-param name="defaulttitle" select="$defaulttitle"/>
  </xsl:apply-templates>
</xsl:template>
<xsl:template match="*" mode="dita2html:section-heading">
  <xsl:param name="defaulttitle"/> <!-- get param by reference -->
  <xsl:variable name="heading">
     <xsl:choose>
      <xsl:when test="*[contains(@class, ' topic/title ')]">
        <xsl:apply-templates select="*[contains(@class, ' topic/title ')][1]" mode="text-only"/>
        <xsl:if test="*[contains(@class, ' topic/title ')][2]">
          <xsl:apply-templates select="." mode="ditamsg:section-with-multiple-titles"/>
        </xsl:if>
      </xsl:when>
      <xsl:when test="@spectitle">
        <xsl:value-of select="@spectitle"/>
      </xsl:when>
      <xsl:otherwise/>
     </xsl:choose>
  </xsl:variable>

  <xsl:variable name="headCount" select="count(ancestor::*[contains(@class, ' topic/topic ')]) + 1"/>
  <xsl:variable name="headLevel">
    <xsl:choose>
      <xsl:when test="$headCount > 6">h6</xsl:when>
      <xsl:otherwise>h<xsl:value-of select="$headCount"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- based on graceful defaults, build an appropriate section-level heading -->
  <xsl:choose>
    <xsl:when test="not($heading = '')">
      <xsl:if test="normalize-space($heading) = ''">
        <!-- hack: a title with whitespace ALWAYS overrides as null -->
        <xsl:comment>no heading</xsl:comment>
      </xsl:if>
      <xsl:apply-templates select="*[contains(@class, ' topic/title ')][1]">
        <xsl:with-param name="headLevel" select="$headLevel"/>
      </xsl:apply-templates>
      <xsl:if test="@spectitle and not(*[contains(@class, ' topic/title ')])">
        <xsl:element name="{$headLevel}">
          <xsl:attribute name="class">sectiontitle</xsl:attribute>
          <xsl:value-of select="@spectitle"/>
        </xsl:element>
      </xsl:if>
    </xsl:when>
    <xsl:when test="$defaulttitle">
      <xsl:element name="{$headLevel}">
        <xsl:attribute name="class">sectiontitle</xsl:attribute>
        <xsl:value-of select="$defaulttitle"/>
      </xsl:element>
    </xsl:when>
    <xsl:otherwise></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/section ')]/*[contains(@class, ' topic/title ')] | 
  *[contains(@class, ' topic/example ')]/*[contains(@class, ' topic/title ')]" name="topic.section_title">
  <xsl:param name="headLevel">
    <xsl:variable name="headCount" select="count(ancestor::*[contains(@class, ' topic/topic ')])+1"/>
    <xsl:choose>
      <xsl:when test="$headCount > 6">h6</xsl:when>
      <xsl:otherwise>h<xsl:value-of select="$headCount"/></xsl:otherwise>
    </xsl:choose>
  </xsl:param>
  <xsl:element name="{$headLevel}">
    <xsl:attribute name="class">sectiontitle</xsl:attribute>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class" select="'sectiontitle'"/>
    </xsl:call-template>
    <xsl:apply-templates/>
  </xsl:element>
</xsl:template>

<xsl:template name="bidi-area" as="xs:boolean">
 <xsl:param name="parentlang">
  <xsl:call-template name="getLowerCaseLang"/>
 </xsl:param>
 <xsl:variable name="direction">
   <xsl:apply-templates select="." mode="get-render-direction">
     <xsl:with-param name="lang" select="$parentlang"/>
   </xsl:apply-templates>
 </xsl:variable>
 <xsl:sequence select="$direction = 'rtl'"/>
</xsl:template>

<!-- Test for URL: returns "url" when the content starts with a URL;
     Otherwise, leave blank -->
<xsl:template name="url-string" as="xs:boolean">
 <xsl:param name="urltext"/>
 <xsl:sequence select="contains($urltext, 'http://') or contains($urltext, 'https://')"/>
</xsl:template>

<!-- For header file processing, pull out the wrapping DIV if one is there -->
<xsl:template match="/div" mode="add-HDF">
  <xsl:apply-templates select="*|comment()|processing-instruction()|text()" mode="add-HDF"/>
</xsl:template>

<xsl:template match="*|@*|comment()|processing-instruction()|text()" mode="add-HDF">
  <xsl:copy>
    <xsl:apply-templates select="*|@*|comment()|processing-instruction()|text()" mode="add-HDF"/>
  </xsl:copy>
</xsl:template>

<!-- ========== Section-like generated content =========== -->

<!-- render any contained footnotes as endnotes.  Links back to reference point -->
<xsl:template name="gen-endnotes">
  <!-- Skip any footnotes that are in draft elements when draft = no -->
  <xsl:apply-templates select="//*[contains(@class, ' topic/fn ')][not( (ancestor::*[contains(@class, ' topic/draft-comment ')] or ancestor::*[contains(@class, ' topic/required-cleanup ')]) and $DRAFT = 'no')]" mode="genEndnote"/>

</xsl:template>

<!-- Catch footnotes that should appear at the end of the topic, and output them. -->
<xsl:template match="*[contains(@class, ' topic/fn ')]" mode="genEndnote">
  <div class="p">
    <xsl:variable name="fnid"><xsl:number from="/" level="any"/></xsl:variable>
    <xsl:variable name="callout" select="@callout"/>
    <xsl:variable name="convergedcallout" select="if (string-length($callout) > 0) then $callout else $fnid"/>
    
    <xsl:call-template name="commonattributes"/>
    <xsl:choose>
      <xsl:when test="@id and not(@id = '')">
        <xsl:variable name="topicid" select="ancestor::*[contains(@class, ' topic/topic ')][1]/@id"/>
        <xsl:variable name="refid" select="concat($topicid, '/', @id)"/>
        <xsl:choose>
          <xsl:when test="key('xref', $refid)">
            <a>
              <xsl:call-template name="setid"/>              
              <sup>
                <xsl:value-of select="$convergedcallout"/>
              </sup>
            </a>
            <xsl:text>  </xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <sup>
              <xsl:value-of select="$convergedcallout"/>
            </sup>
            <xsl:text>  </xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <a>
          <xsl:attribute name="name" select="concat('fntarg_', $fnid)"/>
          <xsl:attribute name="href" select="concat('#fnsrc_', $fnid)"/>
          <sup>
            <xsl:value-of select="$convergedcallout"/>
          </sup>
        </a>
        <xsl:text>  </xsl:text>
      </xsl:otherwise>
    </xsl:choose>
        
    <xsl:apply-templates/>
  </div>
</xsl:template>

<!-- listing of topics from calling context only; can be expanded for nesting -->
<xsl:template name="gen-toc">
  <div>
  <h3 class="sectiontitle">
    <xsl:call-template name="getVariable">
      <xsl:with-param name="id" select="'Contents'"/>
    </xsl:call-template>
  </h3>
   <ul>
    <xsl:for-each select="//topic/title">
     <li>
<!-- this directive provides a "depth" indicator without doing recursive nesting -->
<xsl:value-of select="substring('------', 1, count(ancestor::*))"/>
     <a>
       <xsl:attribute name="href">#<xsl:value-of select="generate-id()"/></xsl:attribute>
       <xsl:value-of select="."/>
     </a>
     <!--recursive call for subtopics here"/-->
     </li>
    </xsl:for-each>
   </ul>
  </div>
</xsl:template>

<!-- ========== SETTINGS ========== -->
<xsl:variable name="trace">no</xsl:variable> <!--set string to 'yes' to turn on trace -->

<!-- set up keys based on xref's "type" attribute: %info-types;|hd|fig|table|li|fn -->
<xsl:key name="topic" match="*[contains(@class, ' topic/topic ')]" use="@id"/> <!-- uses "title" -->
<xsl:key name="fig"   match="*[contains(@class, ' topic/fig ')]"   use="@id"/> <!-- uses "title" -->
<xsl:key name="table" match="*[contains(@class, ' topic/table ')]" use="@id"/> <!-- uses "title" -->
<xsl:key name="li"    match="*[contains(@class, ' topic/li ')]"    use="@id"/> <!-- uses "?" -->
<xsl:key name="fn"    match="*[contains(@class, ' topic/fn ')]"    use="@id"/> <!-- uses "callout?" -->
<xsl:key name="xref"  match="*[contains(@class, ' topic/xref ')]"  use="substring-after(@href, '#')"/> <!-- find xref which refers to footnote. -->

<!-- ========== FORMATTER DECLARATIONS AND GLOBALS ========== -->

<!-- ========== "FORMAT" GLOBAL DECLARATIONS ========== -->

<xsl:variable name="link-top-section">no</xsl:variable><!-- values: yes, no (or any not "yes") -->

<!-- ========== "FORMAT" MACROS  - Table title, figure title, InfoNavGraphic ========== -->
<!--
 | These macros support globally-defined formatting constants for
 | document content.  Some elements have attributes that permit local
 | control of formatting; such logic is part of the pertinent template rule.
 +-->

<!-- Figure caption -->
<xsl:template name="place-fig-lbl">
<xsl:param name="stringName"/>
  <!-- Number of fig/title's including this one -->
  <xsl:variable name="fig-count-actual" select="count(preceding::*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/title ')])+1"/>
  <xsl:variable name="ancestorlang">
    <xsl:call-template name="getLowerCaseLang"/>
  </xsl:variable>
  <xsl:choose>
    <!-- title -or- title & desc -->
    <xsl:when test="*[contains(@class, ' topic/title ')]">
      <span class="figcap">
        <span class="fig--title-label">
         <xsl:choose>      <!-- Hungarian: "1. Figure " -->
          <xsl:when test="$ancestorlang = ('hu', 'hu-hu')">
           <xsl:value-of select="$fig-count-actual"/>
           <xsl:text>. </xsl:text>
           <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Figure'"/>
           </xsl:call-template>
           <xsl:text> </xsl:text>
          </xsl:when>
          <xsl:otherwise>
           <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Figure'"/>
           </xsl:call-template>
           <xsl:text> </xsl:text>
           <xsl:value-of select="$fig-count-actual"/>
           <xsl:text>. </xsl:text>
          </xsl:otherwise>
         </xsl:choose>
        </span>
       <xsl:apply-templates select="*[contains(@class, ' topic/title ')]" mode="figtitle"/>
       <xsl:if test="*[contains(@class, ' topic/desc ')]">
         <xsl:text>. </xsl:text>
       </xsl:if>
      </span>
      <xsl:for-each select="*[contains(@class, ' topic/desc ')]">
       <span class="figdesc">
         <xsl:call-template name="commonattributes"/>
         <xsl:apply-templates select="." mode="figdesc"/>
       </span>
      </xsl:for-each>
    </xsl:when>
    <!-- desc -->
    <xsl:when test="*[contains(@class, ' topic/desc ')]">
      <xsl:for-each select="*[contains(@class, ' topic/desc ')]">
       <span class="figdesc">
         <xsl:call-template name="commonattributes"/>
         <xsl:apply-templates select="." mode="figdesc"/>
       </span>
      </xsl:for-each>
    </xsl:when>
  </xsl:choose>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/title ')]" mode="figtitle">
 <xsl:apply-templates/>
</xsl:template>
<xsl:template match="*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/desc ')]" mode="figdesc">
 <xsl:apply-templates/>
</xsl:template>
<xsl:template match="*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/desc ')]" mode="get-output-class">figdesc</xsl:template>

<!-- These 2 rules are not actually used, but could be picked up by an override -->
<xsl:template match="*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/title ')]" name="topic.fig_title">
  <span><xsl:apply-templates/></span>
</xsl:template>
<!-- These rules are not actually used, but could be picked up by an override -->
<xsl:template match="*[contains(@class, ' topic/fig ')]/*[contains(@class, ' topic/desc ')]" name="topic.fig_desc">
  <span><xsl:apply-templates/></span>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/figgroup ')]/*[contains(@class, ' topic/title ')]" name="topic.figgroup_title">
 <xsl:apply-templates/>
</xsl:template>
  
  <xsl:function name="dita-ot:is-block" as="xs:boolean">
    <xsl:param name="element" as="node()"/>
    <xsl:variable name="class" select="string($element/@class)"/>
    <xsl:sequence select="contains($class, ' topic/body ') or
                          contains($class, ' topic/shortdesc ') or
                          contains($class, ' topic/abstract ') or
                          contains($class, ' topic/title ') or
                          contains($class, ' topic/section ') or 
                          contains($class, ' task/info ') or
                          contains($class, ' topic/p ') or
                          (contains($class, ' topic/image ') and $element/@placement = 'break') or
                          contains($class, ' topic/pre ') or
                          contains($class, ' topic/note ') or
                          contains($class, ' topic/fig ') or
                          contains($class, ' topic/dl ') or
                          contains($class, ' topic/sl ') or
                          contains($class, ' topic/ol ') or
                          contains($class, ' topic/ul ') or
                          contains($class, ' topic/li ') or
                          contains($class, ' topic/sli ') or
                          contains($class, ' topic/itemgroup ') or
                          contains($class, ' topic/section ') or
                          contains($class, ' topic/table ') or
                          contains($class, ' topic/entry ') or
                          contains($class, ' topic/simpletable ') or
                          contains($class, ' topic/stentry ') or
                          contains($class, ' topic/example ')"/>
  </xsl:function>

<!-- ===================================================================== -->

<!-- ========== STUBS FOR USER PROVIDED OVERRIDE EXTENSIONS ========== -->

<xsl:template name="gen-user-head">
  <xsl:apply-templates select="." mode="gen-user-head"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-head">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- it will be placed in the HEAD section of the XHTML. -->
</xsl:template>

<xsl:template name="gen-user-header">
  <xsl:apply-templates select="." mode="gen-user-header"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-header">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- it will be placed in the running heading section of the XHTML. -->
</xsl:template>

<xsl:template name="gen-user-footer">
  <xsl:apply-templates select="." mode="gen-user-footer"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-footer">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- it will be placed in the running footing section of the XHTML. -->
</xsl:template>

<xsl:template name="gen-user-sidetoc">
  <xsl:apply-templates select="." mode="gen-user-sidetoc"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-sidetoc">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- Uncomment the line below to have a "freebie" table of contents on the top-right -->
</xsl:template>

<xsl:template name="gen-user-scripts">
  <xsl:apply-templates select="." mode="gen-user-scripts"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-scripts">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed before the ending HEAD tag -->
</xsl:template>

<xsl:template name="gen-user-styles">
  <xsl:apply-templates select="." mode="gen-user-styles"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-styles">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed before the ending HEAD tag -->
</xsl:template>

<xsl:template name="gen-user-external-link">
  <xsl:apply-templates select="." mode="gen-user-external-link"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-external-link">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed after an external LINK or XREF -->
</xsl:template>


<xsl:template name="gen-user-panel-title-pfx">
  <xsl:apply-templates select="." mode="gen-user-panel-title-pfx"/>
</xsl:template>
<xsl:template match="/|node()|@*" mode="gen-user-panel-title-pfx">
  <!-- to customize: copy this to your override transform, add the content you want. -->
  <!-- It will be placed immediately after TITLE tag, in the title -->
</xsl:template>

<!-- ===================================================================== -->

<!-- ========== DEFAULT PAGE LAYOUT ========== -->

<xsl:template name="chapter-setup">
<html>
  <xsl:call-template name="setTopicLanguage"/>
  <xsl:value-of select="$newline"/>
  <xsl:call-template name="chapterHead"/>
  <xsl:call-template name="chapterBody"/> 
</html>
</xsl:template>

  <xsl:template name="setTopicLanguage">
    <xsl:variable name="childlang">
      <xsl:apply-templates select="/*" mode="get-first-topic-lang"/>
    </xsl:variable>
    <xsl:variable name="direction" as="xs:boolean">
      <xsl:call-template name="bidi-area">
        <xsl:with-param name="parentlang" select="$childlang"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:call-template name="generate-lang">
      <xsl:with-param name="lang" select="$childlang"/>
    </xsl:call-template>
    <xsl:if test="$direction">
      <xsl:attribute name="dir">rtl</xsl:attribute>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="chapterHead">
    <xsl:apply-templates select="." mode="chapterHead"/>
  </xsl:template>
  <xsl:template match="*" mode="chapterHead">
    <head><xsl:value-of select="$newline"/>
      <!-- initial meta information -->
      <xsl:call-template name="generateCharset"/>   <!-- Set the character set to UTF-8 -->
      <xsl:call-template name="generateDefaultCopyright"/> <!-- Generate a default copyright, if needed -->
      <xsl:call-template name="generateDefaultMeta"/> <!-- Standard meta for security, robots, etc -->
      <xsl:call-template name="getMeta"/>           <!-- Process metadata from topic prolog -->
      <xsl:call-template name="copyright"/>         <!-- Generate copyright, if specified manually -->
      <xsl:call-template name="generateCssLinks"/>  <!-- Generate links to CSS files -->
      <xsl:call-template name="generateChapterTitle"/> <!-- Generate the <title> element -->
      <xsl:call-template name="gen-user-head" />    <!-- include user's XSL HEAD processing here -->
      <xsl:call-template name="gen-user-scripts" /> <!-- include user's XSL javascripts here -->
      <xsl:call-template name="gen-user-styles" />  <!-- include user's XSL style element and content here -->
      <xsl:call-template name="processHDF"/>        <!-- Add user HDF file, if specified -->
    </head>
    <xsl:value-of select="$newline"/>
  </xsl:template>
  
  <xsl:template name="generateCharset">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/><xsl:value-of select="$newline"/>
  </xsl:template>
  
  <!-- If there is no copyright in the document, make the standard one -->
  <xsl:template name="generateDefaultCopyright">
    <xsl:if test="not(//*[contains(@class, ' topic/copyright ')])">
      <meta name="copyright">
        <xsl:attribute name="content">
          <xsl:text>(C) </xsl:text>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Copyright'"/>
          </xsl:call-template>
          <xsl:text> </xsl:text>
          <xsl:value-of select="$YEAR"/>
        </xsl:attribute>
      </meta>
      <xsl:value-of select="$newline"/>
      <meta name="DC.rights.owner">
        <xsl:attribute name="content">
          <xsl:text>(C) </xsl:text>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Copyright'"/>
          </xsl:call-template>
          <xsl:text> </xsl:text><xsl:value-of select="$YEAR"/>
        </xsl:attribute>
      </meta>
      <xsl:value-of select="$newline"/>
    </xsl:if>
  </xsl:template>
  
  <!-- Output metadata that should appear in every XHTML topic -->
  <xsl:template name="generateDefaultMeta">
    <xsl:if test="$genDefMeta = 'yes'">
      <meta name="security" content="public"/><xsl:value-of select="$newline"/>
      <meta name="Robots" content="index,follow" /><xsl:value-of select="$newline"/>
    </xsl:if>
  </xsl:template>
  
  <!-- Generate links to CSS files -->
  <xsl:template name="generateCssLinks">
    <xsl:variable name="childlang">
      <xsl:choose>
        <!-- Update with DITA 1.2: /dita can have xml:lang -->
        <xsl:when test="self::dita[not(@xml:lang)]">
          <xsl:for-each select="*[1]"><xsl:call-template name="getLowerCaseLang"/></xsl:for-each>
        </xsl:when>
        <xsl:otherwise><xsl:call-template name="getLowerCaseLang"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="direction">
      <xsl:apply-templates select="." mode="get-render-direction">
        <xsl:with-param name="lang" select="$childlang"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="urltest" as="xs:boolean"> <!-- test for URL -->
      <xsl:call-template name="url-string">
        <xsl:with-param name="urltext" select="concat($CSSPATH, $CSS)"/>
      </xsl:call-template>
    </xsl:variable>
    
    <xsl:choose>
      <xsl:when test="$direction = 'rtl' and $urltest ">
        <link rel="stylesheet" type="text/css" href="{$CSSPATH}{$bidi-dita-css}" />
      </xsl:when>
      <xsl:when test="$direction = 'rtl' and not($urltest)">
        <link rel="stylesheet" type="text/css" href="{$PATH2PROJ}{$CSSPATH}{$bidi-dita-css}" />
      </xsl:when>
      <xsl:when test="$urltest">
        <link rel="stylesheet" type="text/css" href="{$CSSPATH}{$dita-css}" />
      </xsl:when>
      <xsl:otherwise>
        <link rel="stylesheet" type="text/css" href="{$PATH2PROJ}{$CSSPATH}{$dita-css}" />
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$newline"/>
    <!-- Add user's style sheet if requested to -->
    <xsl:if test="string-length($CSS) > 0">
      <xsl:choose>
        <xsl:when test="$urltest">
          <link rel="stylesheet" type="text/css" href="{$CSSPATH}{$CSS}" />
        </xsl:when>
        <xsl:otherwise>
          <link rel="stylesheet" type="text/css" href="{$PATH2PROJ}{$CSSPATH}{$CSS}" />
        </xsl:otherwise>
      </xsl:choose><xsl:value-of select="$newline"/>
    </xsl:if>
    
  </xsl:template>
  
  <xsl:template name="generateChapterTitle">
    <!-- Title processing - special handling for short descriptions -->
    <title>
      <xsl:call-template name="gen-user-panel-title-pfx"/> <!-- hook for a user-XSL title prefix -->
      <xsl:variable name="maintitle"><xsl:apply-templates select="/*[contains(@class, ' topic/topic ')]/*[contains(@class, ' topic/title ')]" mode="text-only"/></xsl:variable>
      <xsl:variable name="ditamaintitle"><xsl:apply-templates select="/dita/*[contains(@class, ' topic/topic ')][1]/*[contains(@class, ' topic/title ')]" mode="text-only"/></xsl:variable>
      <xsl:choose>
        <xsl:when test="string-length($maintitle) > 0"><xsl:value-of select="normalize-space($maintitle)"/></xsl:when>
        <xsl:when test="string-length($ditamaintitle) > 0"><xsl:value-of select="normalize-space($ditamaintitle)"/></xsl:when>
        <xsl:otherwise><xsl:text>***</xsl:text>
          <xsl:apply-templates select="." mode="ditamsg:no-title-for-topic"/>
        </xsl:otherwise>
      </xsl:choose>
    </title><xsl:value-of select="$newline"/>
  </xsl:template>
  
  <!-- Add user's head XHTML code snippet, if specified -->
  <xsl:template name="processHDF">
    <xsl:if test="string-length($HDFFILE) > 0">
      <xsl:apply-templates select="document($HDFFILE, /)" mode="add-HDF"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="chapterBody">
    <xsl:apply-templates select="." mode="chapterBody"/>
  </xsl:template>
  <xsl:template match="*" mode="chapterBody">
    <body>
      <xsl:apply-templates select="." mode="addAttributesToHtmlBodyElement"/>
      <xsl:call-template name="setaname"/>  <!-- For HTML4 compatibility, if needed -->
      <xsl:value-of select="$newline"/>
      <xsl:apply-templates select="." mode="addHeaderToHtmlBodyElement"/>

      <!-- Include a user's XSL call here to generate a toc based on what's a child of topic -->
      <xsl:call-template name="gen-user-sidetoc"/>

      <xsl:apply-templates select="." mode="addContentToHtmlBodyElement"/>
      <xsl:apply-templates select="." mode="addFooterToHtmlBodyElement"/>
    </body>
    <xsl:value-of select="$newline"/>
  </xsl:template>

  <!-- Add all attributes. To add your own additional attributes, use mode="addAttributesToBody". -->
  <xsl:template match="*" mode="addAttributesToHtmlBodyElement">
    <!-- Already put xml:lang on <html>; do not copy to body with commonattributes -->
    <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
    <!--output parent or first "topic" tag's outputclass as class -->
    <xsl:if test="@outputclass">
      <xsl:attribute name="class" select="@outputclass"/>
    </xsl:if>
    <xsl:if test="self::dita">
      <xsl:if test="*[contains(@class, ' topic/topic ')][1]/@outputclass">
        <xsl:attribute name="class" select="*[contains(@class, ' topic/topic ')][1]/@outputclass"/>
      </xsl:if>
    </xsl:if>
    <xsl:call-template name="setid"/>
    <xsl:apply-templates select="." mode="addAttributesToBody"/>
  </xsl:template>

  <!-- Override this template to add any standard attributes to
       the HTML <body> element. Current context is the root
       element of the doc. -->
  <xsl:template match="*" mode="addAttributesToBody">
  </xsl:template>

  <!-- Process <body> content that is appropriate for HTML5 header section. -->
  <xsl:template match="*" mode="addHeaderToHtmlBodyElement">
    <xsl:variable name="header-content" as="node()*">
      <xsl:call-template name="generateBreadcrumbs"/>
      <xsl:call-template name="gen-user-header"/>  <!-- include user's XSL running header here -->
      <xsl:call-template name="processHDR"/>
      <xsl:if test="$INDEXSHOW = 'yes'">
        <xsl:apply-templates select="/*/*[contains(@class, ' topic/prolog ')]/*[contains(@class, ' topic/metadata ')]/*[contains(@class, ' topic/keywords ')]/*[contains(@class, ' topic/indexterm ')] |
                                     /dita/*[1]/*[contains(@class, ' topic/prolog ')]/*[contains(@class, ' topic/metadata ')]/*[contains(@class, ' topic/keywords ')]/*[contains(@class, ' topic/indexterm ')]"/>
      </xsl:if>
    </xsl:variable>

    <xsl:if test="exists($header-content)">
      <header role="banner">
        <xsl:sequence select="$header-content"/>
      </header>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="addContentToHtmlBodyElement">
    <main role="main">
      <article role="article">
        <xsl:attribute name="aria-labelledby">
          <xsl:apply-templates select="*[contains(@class,' topic/title ')] |
                                       self::dita/*[1]/*[contains(@class,' topic/title ')]" mode="return-aria-label-id"/>
        </xsl:attribute>
        <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
        <xsl:apply-templates/> <!-- this will include all things within topic; therefore, -->
                               <!-- title content will appear here by fall-through -->
                               <!-- followed by prolog (but no fall-through is permitted for it) -->
                               <!-- followed by body content, again by fall-through in document order -->
                               <!-- followed by related links -->
                               <!-- followed by child topics by fall-through -->
        <xsl:call-template name="gen-endnotes"/>    <!-- include footnote-endnotes -->
        <xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
      </article>
    </main>
  </xsl:template>

  <xsl:template match="*" mode="addFooterToHtmlBodyElement">
    <xsl:variable name="footer-content" as="node()*">
      <xsl:call-template name="gen-user-footer"/> <!-- include user's XSL running footer here -->
      <xsl:call-template name="processFTR"/>      <!-- Include XHTML footer, if specified -->
    </xsl:variable>
    <xsl:if test="exists($footer-content)">
      <footer role="contentinfo">
        <xsl:sequence select="$footer-content"/>
      </footer>
    </xsl:if>
  </xsl:template>
  
  <xsl:template name="generateBreadcrumbs">
    <!-- Insert previous/next/ancestor breadcrumbs links at the top of the xhtml. -->
    <xsl:apply-templates select="*[contains(@class, ' topic/related-links ')]" mode="breadcrumb"/>
  </xsl:template>
  
  <xsl:template name="processHDR">
    <!-- Add user's running heading XHTML code snippet if requested to -->
    <xsl:if test="string-length($HDRFILE) > 0">
      <xsl:copy-of select="document($HDRFILE, /)"/>      
    </xsl:if>    
  </xsl:template>
  
  <xsl:template name="processFTR">
    <!-- Add user's running footing XHTML code snippet if requested to -->
    <xsl:if test="string-length($FTRFILE) > 0">
      <xsl:copy-of select="document($FTRFILE, /)"/>
    </xsl:if>
  </xsl:template>

  <xsl:template name="get-file-name">
    <xsl:param name="file-path"/>
    <xsl:choose>
    <xsl:when test="contains($file-path, '\')">
        <xsl:call-template name="get-file-name">
            <xsl:with-param name="file-path" select="substring-after($file-path, '\')"/>
        </xsl:call-template>
    </xsl:when>
    <xsl:when test="contains($file-path, '/')">
        <xsl:call-template name="get-file-name">
            <xsl:with-param name="file-path" select="substring-after($file-path, '/')"/>
        </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
        <xsl:value-of select="$file-path"/>
    </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Add for "New <data> element (#9)" in DITA 1.1 -->
  <xsl:template match="*[contains(@class, ' topic/data ')] |
                       *[contains(@class, ' topic/data-about ')]" />

  <!-- Add for "Support foreign content vocabularies such as 
    MathML and SVG with <unknown> (#35) " in DITA 1.1 -->
  <xsl:template match="*[contains(@class, ' topic/foreign ') or contains(@class, ' topic/unknown ')]"/>

  <!-- Add for index-base element. This template is used to prevent
    any processing applied on index-base element -->
  <xsl:template match="*[contains(@class, ' topic/index-base ')]"/>

  <!-- Add for text element.  -->
  <xsl:template match="*[contains(@class, ' topic/text ')]">
    <xsl:apply-templates/>
  </xsl:template>
  
  <!-- By default, ignore desc and force pull-processing -->
  <xsl:template match="*[contains(@class, ' topic/desc ')]" name="topic.desc" priority="-10"/>
  
  <!-- Add for bodydiv  and sectiondiv-->
  <xsl:template match="*[contains(@class, ' topic/bodydiv ') or contains(@class, ' topic/sectiondiv ')]">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <!-- Function to look up a target in the keyref file -->
  <xsl:template match="*" mode="find-keyref-target">
    <!-- Deprecated since 2.1 -->
    <xsl:param name="keys" select="@keyref"/>
    <!-- Deprecated since 2.1 -->
    <xsl:param name="target" select="@href"/>
    
    <xsl:choose>
      <xsl:when test="contains($target, '://')">
        <xsl:value-of select="$target"/>
      </xsl:when>
      <!-- edited  on 2010-12-17 for keyref bug:3114411 start-->
      <xsl:when test="contains($target, '#')">
        <xsl:value-of select="concat($PATH2PROJ, substring-before(substring-before($target, '#'), '.'), $OUTEXT, '#', substring-after($target, '#'))"/>
      </xsl:when>
      <xsl:when test="$target = ''">
        <xsl:value-of select="$OUTEXT"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="concat($PATH2PROJ, substring-before($target, '.'), $OUTEXT)"/>
      </xsl:otherwise>
      <!-- edited  on 2010-12-17 for keyref bug:3114411 end-->
    </xsl:choose>
  </xsl:template>

  <!-- Deprecated since 2.1 -->
  <!-- This template pulls in topic/title -->
  <!-- 20090330: Add error checking to ensre $keys is defined, that the key
                 is defined in KEYREF-FILE, and that $target != '' -->
  <xsl:template match="*" mode="pull-in-title">
    <xsl:param name="type"/>
    <xsl:param name="displaytext" select="''"/>
    <xsl:param name="keys" select="@keyref"/>
    
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX069W'"/>
      <xsl:with-param name="msgparams">%1=pull-in-title</xsl:with-param>
    </xsl:call-template>
    <xsl:choose>
      <xsl:when test="$displaytext = '' and $keys != ''">
        <xsl:variable name="target">
          <xsl:variable name="keydef" select="$keydefs//*[@keys = $keys]"/>
          <xsl:if test="$keydef">
            <xsl:choose>
              <xsl:when test="contains($keydef/@href, '#')">
                <xsl:value-of select="substring-before($keydef/@href, '#')"/>
              </xsl:when>
              <xsl:when test="$keydef/@href">
                <xsl:value-of select="$keydef/@href"/>
              </xsl:when>
            </xsl:choose>
          </xsl:if>
        </xsl:variable>
        <xsl:if test="not($target = '' or contains($target, '://'))">
          <xsl:value-of select="(document(concat($WORKDIR, $PATH2PROJ, $target))//*[contains(@class, ' topic/title ')][normalize-space(.) != ''])[1]"/>
        </xsl:if>
      </xsl:when>
      <xsl:when test="normalize-space(.) = ''">
        <xsl:value-of select="$displaytext"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  <!-- This template converts phrase-like elements into links based on keyref. -->
  <!-- 20090331: Update to ensure cite with keyref continues to use <cite>,
                 plus move common code to single template -->
  <xsl:template match="*" mode="turning-to-link">
    <xsl:param name="keys" select="@keyref" as="xs:string?"/>
    <xsl:param name="type" select="name()" as="xs:string"/>
    <xsl:variable name="elementName" as="xs:string">
      <xsl:choose>
        <xsl:when test="$type = 'cite'">cite</xsl:when>
        <xsl:otherwise>span</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <a>
      <xsl:apply-templates select="." mode="add-linking-attributes"/>
      <xsl:apply-templates select="." mode="add-desc-as-hoverhelp"/>
      <xsl:element name="{$elementName}">
        <xsl:call-template name="commonattributes">
          <xsl:with-param name="default-output-class">
            <xsl:if test="normalize-space($type) != name()">
              <xsl:value-of select="$type"/>
            </xsl:if>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:apply-templates/>
      </xsl:element>
    </a>
  </xsl:template>

  <!-- Deprecated since 2.1 -->
  <xsl:template match="*" mode="common-processing-phrase-within-link">
    <xsl:param name="type"/>
    
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX069W'"/>
      <xsl:with-param name="msgparams">%1=common-processing-phrase-within-link</xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="commonattributes">
      <xsl:with-param name="default-output-class">
        <xsl:if test="normalize-space($type) != name()">
          <xsl:value-of select="$type"/>
        </xsl:if>
      </xsl:with-param>
    </xsl:call-template>
    <xsl:call-template name="setidaname"/>
    <xsl:apply-templates/>
  </xsl:template>

  <!-- MESSAGES: Refactoring places each message in a moded template, so that users
       may more easily override a message for one or all cases. -->
  <xsl:template match="*" mode="ditamsg:no-glossentry-for-key">
    <xsl:param name="matching-keys"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX058W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$matching-keys"/>;%2=<xsl:value-of select="name()"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:no-title-for-topic">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX037W'"/>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:longdescref-on-object">
    <xsl:call-template name="output-message">
     <xsl:with-param name="id" select="'DOTX038I'"/>
     <xsl:with-param name="msgparams">%1=<xsl:value-of select="name(.)"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:required-cleanup-in-content">
    <xsl:call-template name="output-message">
     <xsl:with-param name="id" select="'DOTX039W'"/>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:draft-comment-in-content">
    <xsl:call-template name="output-message">
     <xsl:with-param name="id" select="'DOTX040I'"/>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:section-with-multiple-titles">
    <xsl:param name="actual-element" select="name(.)"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX041W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$actual-element"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>

</xsl:stylesheet>
