<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<!--
  Fixes: add "-" to start of class attribute on generated elements (<linktext>, <desc>)
         links to elements inside abstract do not retrieve text
         Get link text for <link> elements that include <desc> but no link text
         Get link text for <xref> elements that include <desc> but no link text
         Get short description for <xref> elements that contain link text but no <desc>
         Fig and table numbering is now specialization aware
         XREF to dlentry looked for <dlterm>, should be <dt>
         No space between "Figure" and number in "Figure 1" reference
         No space between "Table" and number in "Table 1" reference
         Reference to table without @type used a title instead of Table N; now uses Table N to
             be consistent with typed reference and with figures
         Function to determine class had collapsed <xsl:text> </xsl:text> into <xsl:text/>,
             this caused the previous bug with tables
         Wrapping an </xsl:otherwise> to a newline added many spaces to '#none#' in some cases;
             resulted in type attributes getting set to "#none#&#xA;          &#xA;        "
         Hungarian references to figure and table should use Hungarian rules
         draft-comment and required-cleanup were pulled in to link text and hover help
         Shortdesc fixes:
         - If an element within a topic is the target, only look at that element for a desc (not the topic)
         - If a file has many topics, do not pull every shortdesc when targeting a topic
         - If a target topic uses abstract, add a space between shortdesc's in the abstract
         - If the target topic does not have a shortdesc, do not fall back to shortdesc from another topic
-->
<!-- Refactoring completed March and April 2007. The code now contains 
     numerous hooks that can be overridden using modes. Most noteworthy:
mode="topicpull:inherit-attribute"
     Can be used to selectively modify how attributes are inherited on a specific element
mode="topicpull:get-stuff_get-linktext" and mode="topicpull:get-stuff_get-shortdesc"
     Can be used to determine how link text or shortdesc are retrieved for some types of references
mode="topicpull:getlinktext" and more specific modes "topicpull:getlinktext_*"
     Can be used to modify retrieved link text for specific types of elements
mode="topicpull:figure-linktext" and mode="topicpull:table-linktext"
     Can be used to modify link style for table and figure references; can
     also be used to add support for languages that use different orders.
     Note also the TABLELINK and FIGURELINK parameters.
     -->
<!-- 20090903 RDA: added <?ditaot gentext?> and <?ditaot linktext?> PIs for RFE 1367897.
                   Allows downstream processes to identify original text vs. generated link text. -->
          
<xsl:stylesheet version="2.0" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:topicpull="http://dita-ot.sourceforge.net/ns/200704/topicpull"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="dita-ot topicpull ditamsg xs">
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-textonly.xsl"/>
  <!-- Define the error message prefix identifier -->
  <!-- Deprecated since 2.3 -->
  <xsl:variable name="msgprefix">DOTX</xsl:variable>
  <!-- Deprecated since 2.4 -->
  <xsl:param name="DBG" select="'no'"/>

  <!-- Set the format for generated text for links to tables and figures.   -->
  <!-- Recognized values are 'NUMBER' (Table 5) and 'TITLE' (Table Caption) -->
  <xsl:param name="TABLELINK">NUMBER</xsl:param>
  <xsl:param name="FIGURELINK">NUMBER</xsl:param>
  <xsl:param name="remove-broken-links" as="xs:string?"/>
  <!-- Check whether the onlytopicinmap is turned on -->
  <xsl:param name="ONLYTOPICINMAP" select="'false'"/>
  
  <!-- Establish keys for the counting of figures, tables, and anything else -->
  <!-- To remove something from the figure count, create the same key in an override.
       Match all items to be excluded. Set the use attribute to 'exclude'. -->
  <xsl:key name="count.topic.fig"
           match="*[contains(@class, ' topic/fig ')][*[contains(@class, ' topic/title ')]]"
           use="'include'"/>
  <xsl:key name="count.topic.table"
           match="*[contains(@class, ' topic/table ')][*[contains(@class, ' topic/title ')]]"
           use="'include'"/>
  
  <xsl:key name="nontopicElementsById" match="*[@id][not(dita-ot:is-topic(.))]" use="@id"/>
  <xsl:key name="topicsById" match="*[contains(@class, ' topic/topic ')][@id]" use="@id"/>
  
  
  <!-- ========================
       Functions
       ======================== -->
  
  <xsl:function name="dita-ot:get-inherited-attribute-value" as="xs:string?">
    <xsl:param name="context" as="element()"/>
    <xsl:param name="attributeName" as="xs:string"/>
    <xsl:param name="defaultValue" as="xs:string?"/>
    
    <xsl:variable name="specifiedValue" as="xs:string?">
      <xsl:for-each select="$context">
        <xsl:call-template name="topicpull:inherit">
          <xsl:with-param name="attrib" select="$attributeName" as="xs:string"/>
        </xsl:call-template>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence 
      select="if (exists($specifiedValue)) 
      then $specifiedValue 
      else $defaultValue"/>
    
  </xsl:function>
  
  <xsl:function name="dita-ot:get-link-scope" as="xs:string?">
    <xsl:param name="context" as="element()"/>
    <xsl:sequence select="dita-ot:get-link-scope($context, ())"/>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-link-scope" as="xs:string?">
    <xsl:param name="context" as="element()"/>
    <xsl:param name="default" as="xs:string?"/>
    <xsl:sequence 
      select="dita-ot:get-inherited-attribute-value($context, 'scope', $default)"/>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-link-target-type" as="xs:string?">
    <xsl:param name="context" as="element()"/>
    <xsl:sequence select="dita-ot:get-link-target-type($context, ())"/>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-link-target-type" as="xs:string?">
    <xsl:param name="context" as="element()"/>
    <xsl:param name="default" as="xs:string?"/>
    <xsl:sequence 
      select="dita-ot:get-inherited-attribute-value($context, 'type', $default)"/>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-link-format" as="xs:string?">
    <xsl:param name="context" as="element()"/>
    <xsl:sequence 
      select="dita-ot:get-link-format($context, ())"/>
  </xsl:function>
  
  <xsl:function name="dita-ot:get-link-format" as="xs:string?">
    <xsl:param name="context" as="element()"/>
    <xsl:param name="default" as="xs:string?"/>
    <xsl:sequence 
      select="dita-ot:get-inherited-attribute-value($context, 'format', $default)"/>
  </xsl:function>
  
  <xsl:function name="dita-ot:is-link" as="xs:boolean">
    <xsl:param name="node"/>
    <xsl:sequence select="contains($node/@class,' topic/xref ') or
      ($node/@href and not(contains($node/@class,' delay-d/anchorkey ')) and (some $c in $link-classes satisfies contains($node/@class, $c)))"/>
  </xsl:function>
  
  <!-- Given a link element, attempt to resolve its @href 
       to a document if scope is @local and @type is
       dita or ditamap.
       
       @param linkElement The element making the link
       @return The referenced document or an empty sequence if
               the resource part of the URI (if any) cannot be
               resolved. If there is no resouce part then the 
               link element's own document is returned.
    -->
  <xsl:function name="dita-ot:getTargetDoc" as="document-node()?">
    <xsl:param name="linkElement" as="element()"/>
    
    <xsl:variable name="targetURI" as="xs:string?" select="$linkElement/@href"/>
    <xsl:choose>
      <xsl:when test="normalize-space($targetURI) = ''">
        <xsl:sequence select="()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="resourcePart" as="xs:string?" 
          select="tokenize($targetURI, '#')[1]"/>
        <xsl:variable name="scope" select="dita-ot:get-link-scope($linkElement, 'local')" as="xs:string"/>
        <xsl:variable name="format" select="dita-ot:get-link-format($linkElement, 'dita')" as="xs:string"/>
        <xsl:choose>
          <xsl:when test="not($scope = ('local'))">
            <!-- Not a local-scope link, don't resolve it.
              
                 FIXME: For peer-scope references may need to actually do resolution
                        for cross-deliverable link key references. Not sure how that
                        is being handled in preprocessing.
              -->
            <xsl:sequence select="()"/>
          </xsl:when>
          <xsl:when test="not($format = ('dita', 'ditamap'))">
            <!-- Local scope but not a dita or ditamap target, cannot resolve. -->
            <xsl:sequence select="()"/>
          </xsl:when>
          <xsl:when test="empty($resourcePart)">
            <xsl:sequence select="root($linkElement)"/>
          </xsl:when>
          <xsl:otherwise>
            
            <xsl:variable name="targetDoc" as="document-node()?"
              select="document($resourcePart, $linkElement)"/>
            <xsl:choose>
              <xsl:when test="empty($targetDoc)">
                <!-- Report the failure to resolve the URI -->
                <xsl:apply-templates select="$linkElement" mode="ditamsg:missing-href-target">
                  <xsl:with-param name="file" select="$targetURI"/>
                </xsl:apply-templates>                
                <xsl:sequence select="()"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:sequence select="$targetDoc"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <!-- Given a document that should contain a topic and, optionally,
       the ID of the topic within that document, return
       the topic, if found.
       
       If topicid is not specified then the topic must be the first
       topic in the document.
       
       @param doc (optional) Document that may contain the target topic
       @param topicid (Optional) The ID of the target topic       
       @return The referenced topic, or empty sequence if topic is not found.       
    -->
  <xsl:function name="dita-ot:getTargetTopic" as="element()?">
    <xsl:param name="doc" as="document-node()?"/>
    <xsl:param name="topicid" as="xs:string?"/>
    
    <xsl:variable name="target" as="element()?"
      select="if (empty($doc)) then () 
      else 
      if (empty($topicid) or $topicid = '') 
         then ($doc//*[contains(@class, ' topic/topic ')])[1]
         else key('topicsById', $topicid, $doc)[1]"/>
    <xsl:sequence select="$target"/>
  </xsl:function>
  
  <!-- Given a linking element that has a non-empty @href value,
       a local scope, and a dita format, attempt to resolve it to 
       a target element.
       
       This function reports any failures to resolve the reference.
    -->
  <xsl:function name="dita-ot:getTargetElement" as="element()?">
    <xsl:param name="linkElement" as="element()"/>
    
    <!--    <xsl:message> + [DEBUG] dita-ot:getTargetElement(): linkElement: 
     type: <xsl:value-of select="name($linkElement)"/>
     href: <xsl:value-of select="$linkElement/@href"/>
     scope: <xsl:value-of select="$linkElement/@scope"/>      
    </xsl:message>    
-->    
    <!-- Note that document() needs to be relative to the current element
         in order to reflect any @xml:base attributes, not the root
         of the current document.
      -->
    <xsl:variable name="doc" 
      select="dita-ot:getTargetDoc($linkElement)" as="document-node()?"/>
    
    <xsl:choose>
      <xsl:when test="exists($doc)">
        <!-- If we have a doc then the scope must be local (or maybe peer)
             and the format must be dita or ditamap.
          -->
        <xsl:variable name="targetTopic" as="element()?"
          select="dita-ot:getTargetTopic($doc, dita-ot:get-topic-id(string($linkElement/@href)))"/>
        
        <xsl:choose>
          <xsl:when test="exists($targetTopic)">
            <xsl:variable name="elemid" as="xs:string?" 
              select="dita-ot:get-element-id(string($linkElement/@href))"/>                
            <xsl:choose>
              <xsl:when test="exists($elemid)">
                <xsl:variable name="candidates" as="element()*">
                  <xsl:sequence select="key('nontopicElementsById', $elemid, $targetTopic)[1]"/>
                </xsl:variable>
                <xsl:sequence select="$candidates[1]"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:sequence select="$targetTopic"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="()"/>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:function>

  <xsl:function name="dita-ot:is-topic" as="xs:boolean">
    <xsl:param name="element" as="element()"/>
    <xsl:variable name="result" as="xs:boolean"
      select="contains($element/@class, ' topic/topic ')"/>
    <xsl:sequence select="$result"/>
  </xsl:function>
  
  
  <!-- ========================
       Templates
       ======================== -->
  
  <!-- Process a link in the related-links section. Retrieve link text, type, and
       description if possible (and not already specified locally). -->
  <xsl:template match="*[contains(@class, ' topic/link ')]">    
    <xsl:if test="@href=''">
      <xsl:apply-templates select="." mode="ditamsg:empty-href"/>
    </xsl:if>
        
    <xsl:variable name="targetElement" as="element()?" select="dita-ot:getTargetElement(.)"/>
    
    <xsl:choose>
      <xsl:when test="$remove-broken-links = 'true' and empty($targetElement)">
        <xsl:call-template name="output-message">
          <xsl:with-param name="id" select="'DOTX073I'"/>
          <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <!--copy existing explicit attributes-->
          <xsl:apply-templates select="@*"/>
          <!--copy inheritable attributes that aren't already explicitly defined-->
          <!--@type|@format|@scope|@importance|@role-->
    
          <!--need to create type, format, scope variables regardless of whether they exist, for passing as a parameter to getstuff template-->
          <xsl:variable name="type" as="xs:string?" select="dita-ot:get-link-target-type(.)"/>
          
          <xsl:variable name="format" as="xs:string?" select="dita-ot:get-link-format(.)"/>
          <xsl:variable name="scope" as="xs:string?" select="dita-ot:get-link-scope(.)"/>
          
          <xsl:if test="empty(@type) and $type">
            <xsl:attribute name="type" select="$type"/>
          </xsl:if>
          <xsl:if test="empty(@format) and $format">
            <xsl:attribute name="format" select="$format"/>
          </xsl:if>
          <xsl:if test="empty(@scope) and $scope">
            <xsl:attribute name="scope" select="$scope"/>
          </xsl:if>
    
          <xsl:if test="empty(@importance)">
            <xsl:variable name="importance" as="xs:string?"
              select="dita-ot:get-inherited-attribute-value(., 'importance', ())"/>
            <xsl:if test="exists($importance)">
              <xsl:attribute name="importance" select="$importance"/>
            </xsl:if>
          </xsl:if>
          <xsl:if test="empty(@role)">
            <xsl:variable name="role" as="xs:string?"
              select="dita-ot:get-inherited-attribute-value(., 'role', ())"/>
            <xsl:if test="exists($role)">
              <xsl:attribute name="role" select="$role"/>
            </xsl:if>
          </xsl:if>
    
          <xsl:choose>
            <xsl:when test="@type and *[contains(@class, ' topic/linktext ')] and *[contains(@class, ' topic/desc ')]">
              <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>
              <xsl:apply-templates/>
            </xsl:when>
            <xsl:otherwise>
              <!--grab type, text and metadata, as long there's an href to grab from, otherwise allow local linktext, otherwise error-->
              <xsl:choose>
                <xsl:when test="@href=''">
                  <xsl:apply-templates/>
                </xsl:when>
                <xsl:when test="@href">
                  <xsl:apply-templates select="." mode="topicpull:get-stuff">
                    <xsl:with-param name="localtype" select="$type" as="xs:string?"/>
                    <xsl:with-param name="targetElement" select="$targetElement" as="element()?"/>
                  </xsl:apply-templates>
                </xsl:when>
                <xsl:when test="*[contains(@class, ' topic/linktext ')]">
                  <xsl:apply-templates/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:apply-templates select="." mode="ditamsg:missing-href"/>
                  <xsl:apply-templates/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- 2007.03.13: Update inheritance to check specific elements and attributes.
       Similar to the inheritance template in mappull, except that it stops at related links. -->
  <xsl:template name="topicpull:inherit">
    <xsl:param name="attrib"/>
    <xsl:apply-templates select="." mode="topicpull:inherit-from-self-then-ancestor">
      <xsl:with-param name="attrib" select="$attrib"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Match the attribute which we are trying to inherit -->
  <xsl:template match="@*" mode="topicpull:inherit-attribute">
    <xsl:value-of select="."/>
  </xsl:template>

  <!-- If an attribute is specified locally, set it. Otherwise, try to inherit from ancestors. -->
  <xsl:template match="*" mode="topicpull:inherit-from-self-then-ancestor">
    <xsl:param name="attrib"/>
    <xsl:variable name="attrib-here" as="xs:string?">
      <xsl:if test="@*[local-name()=$attrib]">
        <xsl:value-of select="@*[local-name()=$attrib]"/>
      </xsl:if>
    </xsl:variable>
    <xsl:choose>
      <!-- Any time the attribute is specified on this element, use it -->
      <xsl:when test="exists($attrib-here)">
        <xsl:value-of select="$attrib-here"/>
      </xsl:when>
      <!-- Otherwise, use normal inheritance fallback -->
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="topicpull:inherit-attribute">
          <xsl:with-param name="attrib" select="$attrib" as="xs:string"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Match an element when trying to inherit an attribute. Put the value of the attribute in $attrib-here.
         * If the attribute is present and should be used ($attrib=here!=''), then use it
         * If we are at the related-links element, attribute can't be inherited, so return #none#
         * Anything else, move on to parent
         -->
  <xsl:template match="*" mode="topicpull:inherit-attribute">
    <xsl:param name="attrib"/>
    <xsl:variable name="attrib-here" as="xs:string?">
      <xsl:apply-templates select="@*[local-name()=$attrib]" mode="topicpull:inherit-attribute"/>
    </xsl:variable>
    <xsl:choose>
      <!-- Any time the attribute is specified on this element, use it -->
      <xsl:when test="exists($attrib-here)">
        <xsl:value-of select="$attrib-here"/>
      </xsl:when>
      <xsl:when test="contains(@class,' topic/related-links ')">
        <xsl:sequence select="()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="parent::*" mode="#current">
          <xsl:with-param name="attrib" select="$attrib"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Set the specified attribute is a value is not specified
       locally and a value is actually inherited.
    -->
  <xsl:template match="*" mode="topicpull:inherit-and-set-attribute">
    <xsl:param name="attrib"/>
    <xsl:variable name="inherited-value">
      <xsl:apply-templates select="." mode="topicpull:inherit-from-self-then-ancestor">
        <xsl:with-param name="attrib" select="$attrib"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:if test="exists($inherited-value)">
      <xsl:attribute name="{$attrib}" select="$inherited-value"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' svg-d/svgref ')]" priority="10">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Process an in-line cross reference. Retrieve link text, type, and
       description if possible (and not already specified locally). -->
  <xsl:template match="*[dita-ot:is-link(.)]">
    <xsl:choose>
      <xsl:when test="normalize-space(@href)='' or empty(@href)">
        <xsl:if test="empty(@keyref) and @href">
          <!-- If keyref is specified, keyref code can generate message about unresolved key -->
          <xsl:apply-templates select="." mode="ditamsg:empty-href"/>
        </xsl:if>
        <xsl:copy>
          <xsl:apply-templates select="@*"/>
          <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>
          <xsl:apply-templates select="*|comment()|processing-instruction()|text()"/>
        </xsl:copy>
      </xsl:when>
      <!-- replace "*|text()" with "normalize-space()" to handle xref without 
        valid link content, in this situation, the xref linktext should be 
        grabbed from href target. -->
      <!-- replace normalize-space() with test for actual valid content. If there is link text
           and a <desc> for hover help, do not try to retrieve anything. -->
      <xsl:when test="(text()|*[not(contains(@class,' topic/desc '))]) and *[contains(@class,' topic/desc ')]">
        <xsl:copy>
          <xsl:apply-templates select="@*"/>
          <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>
          <xsl:apply-templates select="*|comment()|processing-instruction()|text()"/>
        </xsl:copy>
      </xsl:when>
      <xsl:when test="@href and not(@href='')">
        <xsl:copy>
          <xsl:apply-templates select="@*"/>
          <!--create variables for attributes that will be passed by parameter to the getstuff template (which is shared with link, which needs the attributes in variables to save doing inheritance checks for each one)-->
          <xsl:variable name="type" as="xs:string?" select="@type"/>
          <xsl:variable name="format" as="xs:string?" select="@format"/>
          <xsl:variable name="scope" as="xs:string?" select="@format"/>
          <!--grab type, text and metadata, as long there's an href to grab from, otherwise error-->
          <xsl:apply-templates select="." mode="topicpull:get-stuff">
            <xsl:with-param name="localtype" select="$type" as="xs:string?"/>
          </xsl:apply-templates>
        </xsl:copy>
      </xsl:when>
      <!-- Ignore <xref></xref>, <xref href=""></xref> -->
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="ditamsg:missing-href"/>
        <xsl:copy>
          <xsl:apply-templates select="@*"/>
          <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>
          <xsl:apply-templates select="*|comment()|processing-instruction()|text()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Verify that a locally specified type attribute matches the determined target type.
       If it does not, generate a message. -->
  <xsl:template match="*" mode="topicpull:verify-type-attribute">
    <xsl:param name="type"/>            <!-- Type value specified on the link -->
    <xsl:param name="targetElement" as="element()"/>
    
    <xsl:variable name="actual-name" select="name($targetElement)" as="xs:string"/>
    <xsl:variable name="actual-class" select="$targetElement/@class" as="xs:string"/>
    <xsl:variable name="isTopic" as="xs:boolean" select="contains($targetElement/@class, ' topic/topic ')"/>
    
    <xsl:choose>
      <!-- The type is correct; concept typed as concept, newtype defined as newtype -->
      <xsl:when test="$type=$actual-name"/>
      <!-- If the actual class contains the specified type; reference can be called topic,
         specializedReference can be called reference -->
      <xsl:when test="($isTopic and contains($actual-class,concat(' ',$type,'/',$type,' '))) or
                      (not($isTopic) and contains($actual-class,concat('/',$type,' ')))">
        <xsl:apply-templates select="." mode="ditamsg:type-attribute-not-specific">
          <xsl:with-param name="targetting" select="if ($isTopic) then 'topic' else 'element'"/>
          <xsl:with-param name="type" select="$type"/>
          <xsl:with-param name="actual-name" select="$actual-name"/>
        </xsl:apply-templates>
      </xsl:when>
      <!-- Otherwise: incorrect type is specified -->
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="ditamsg:type-attribute-incorrect">
          <xsl:with-param name="targetting" select="if ($isTopic) then 'topic' else 'element'"/>
          <xsl:with-param name="type" select="$type"/>
          <xsl:with-param name="actual-name" select="$actual-name"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Get link text, type, and short description for a link or cross reference.
       If specified locally, use the local value, otherwise retrieve from target. -->
  <xsl:template match="*" mode="topicpull:get-stuff">
    <xsl:param name="localtype" as="xs:string?"/>
    <xsl:param name="targetElement" as="element()?"
      select="dita-ot:getTargetElement(.)"/>
    
    <xsl:choose>
      <xsl:when test="exists($targetElement)">
        <!--type - grab type from target, if not defined locally -->
        <xsl:variable name="type" as="xs:string?">
          <xsl:apply-templates select="." mode="topicpull:get-stuff_get-type">
            <xsl:with-param name="localtype" select="$localtype"/>
            <xsl:with-param name="targetElement" select="$targetElement" as="element()"/>
          </xsl:apply-templates>
        </xsl:variable>
        
        <!--now, create the type attribute, if the type attribute didn't exist locally but was retrieved successfully-->
        <xsl:if test="empty($localtype) and $type">
          <xsl:attribute name="type" select="$type"/>
        </xsl:if>
        
        <!-- Verify that the type was correct, if specified locally, and DITA target is available -->
        <xsl:apply-templates select="." mode="topicpull:get-stuff_verify-type">
          <xsl:with-param name="localtype" select="$localtype"/>
          <xsl:with-param name="targetElement" select="$targetElement" as="element()"/>
        </xsl:apply-templates>
        
        <!--create class value string implied by the link's type, used for comparison with class strings in the target topic for validation-->
        <xsl:variable name="classval" as="xs:string" 
          select="if (dita-ot:is-topic($targetElement))
                     then tokenize(substring($targetElement/@class, 3), ' ')[1]
                     else concat('/', substring-after(tokenize(substring($targetElement/@class, 3), ' ')[1], '/'))
          "/>
        
        <!--linktext-->
        <xsl:apply-templates select="." mode="topicpull:get-stuff_get-linktext">
          <xsl:with-param name="targetElement" select="$targetElement" as="element()"/>
        </xsl:apply-templates>
        
        <!-- shortdesc -->
        <xsl:apply-templates select="." mode="topicpull:get-stuff_get-shortdesc">
          <xsl:with-param name="targetElement" select="$targetElement" as="element()"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <!-- Scope must be peer or external or format is not dita, use any local text. -->
        <xsl:variable name="format" as="xs:string?"
          select="dita-ot:get-link-format(.)"/>
        <xsl:variable name="scope" as="xs:string?"
          select="dita-ot:get-link-scope(., 'local')"/>
        <xsl:choose>
          <xsl:when test="contains(@class,' topic/link ') and *[not(contains(@class, ' topic/desc '))]">
            <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>
            <xsl:apply-templates select="*|comment()|processing-instruction()"/>
          </xsl:when>
          <xsl:when test="normalize-space(.) != '' or *[not(contains(@class, ' topic/desc '))]">
            <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>
            <xsl:apply-templates select="text()|*[not(contains(@class, ' topic/desc '))]|comment()|processing-instruction()"/>
          </xsl:when>
          <xsl:when test="$scope = ('external') and $format = ('dita', 'ditamap')">
            <!-- Defer to the final output process - and leave it 
                   to the final output process to emit an error msg
                -->
            <xsl:sequence select="()"/>
          </xsl:when>
          <xsl:when test="normalize-space(@href) = ''">
            <xsl:sequence select="()"/>
          </xsl:when>          
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- ******************************************************************************
       Individual portions of get-stuff processing, broken apart for easy overriding.
       If a template overrides all of get-stuff, most of these templates can still be
       used so as to avoid duplicating processing code in the override.
       ************************************************************************** -->


  <!-- Get the type from target, if not defined locally -->
  <xsl:template match="*" mode="topicpull:get-stuff_get-type" as="xs:string?">
    <xsl:param name="localtype"/>
    <xsl:param name="targetElement" as="element()"/>
    <xsl:choose>
      <!--just use localtype if it's not "none"-->
      <xsl:when test="exists($localtype)"><xsl:value-of select="$localtype"/></xsl:when>
      <!--check whether it's worth trying to retrieve-->
      <!--grab from target topic-->
      <xsl:when test="exists($targetElement)">
        <xsl:value-of select="local-name($targetElement)"/>
      </xsl:when>
      <xsl:otherwise>
        <!--tested both conditions for localtype (exists or not), so no otherwise-->
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- Find the class attribute of the reference topic. Determine if the specified type
       exists in that class attribute. -->
  <xsl:template match="*" mode="topicpull:get-stuff_verify-type">
    <xsl:param name="localtype"/>
    <xsl:param name="targetElement" as="element()?"/>
    
    <xsl:if test="exists($localtype) and $targetElement">
      <xsl:apply-templates select="." mode="topicpull:verify-type-attribute">
        <xsl:with-param name="type" select="$localtype"/>
        <xsl:with-param name="actual-class" select="$targetElement/@class"/>
        <xsl:with-param name="actual-name" select="local-name($targetElement)"/>
        <xsl:with-param name="targetElement" as="element()" select="$targetElement"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>

  <!-- Get the short description for a link or xref -->
  <xsl:template match="*" mode="topicpull:get-stuff_get-shortdesc">
    <xsl:param name="targetElement" as="element()?"/>
    
    <xsl:choose>
      <!--if there's already a desc, copy it-->
      <xsl:when test="*[contains(@class, ' topic/desc ')]">
        <xsl:apply-templates select="." mode="topicpull:add-usershortdesc-PI"/>
        <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
      </xsl:when>
      <!--if the target is inaccessible, don't do anything - shortdesc is optional -->
      <xsl:when test="empty($targetElement)"/>
      <!--otherwise try pulling shortdesc from target-->
      <xsl:otherwise>
        <xsl:variable name="shortdesc">
          <xsl:apply-templates select="." mode="topicpull:getshortdesc">
            <xsl:with-param name="targetElement" as="element()" select="$targetElement"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:if test="exists($shortdesc) and not(normalize-space($shortdesc) = '')">
          <xsl:apply-templates select="." mode="topicpull:add-genshortdesc-PI"/>
          <desc class="- topic/desc ">
            <xsl:apply-templates select="$shortdesc"/>
          </desc>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Ignore desc in elements that do now support it. -->
  <xsl:template match="*[contains(@class,' topic/cite ') or
                         contains(@class,' topic/dt ') or
                         contains(@class,' topic/keyword ') or
                         contains(@class,' topic/term ') or
                         contains(@class,' topic/ph ') or
                         contains(@class,' topic/indexterm ') or
                         contains(@class,' topic/index-base ') or
                         contains(@class,' topic/indextermref ')]"
                mode="topicpull:get-stuff_get-shortdesc" priority="10"/>

  <!-- Get the link text for a link or cross reference. If specified locally, use that. Otherwise,
       work with the target to get the text. -->
  <xsl:template match="*" mode="topicpull:get-stuff_get-linktext">
    <xsl:param name="targetElement" as="element()"/>
    
    <xsl:choose>
      <xsl:when test="contains(@class,' topic/link ') and *[not(contains(@class, ' topic/desc '))]">
        <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>
        <xsl:apply-templates select="*[not(contains(@class, ' topic/desc '))]|comment()|processing-instruction()"/>
      </xsl:when>
      <xsl:when test="dita-ot:is-link(.) and (normalize-space(.) != '' or *[not(contains(@class, ' topic/desc '))])">
        <xsl:apply-templates select="." mode="topicpull:add-usertext-PI"/>          
        <xsl:apply-templates select="text()|*[not(contains(@class, ' topic/desc '))]|comment()|processing-instruction()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="linktext">
          <xsl:apply-templates select="." mode="topicpull:getlinktext">
            <xsl:with-param name="targetElement" as="element()" select="$targetElement"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:if test="exists($linktext) and dita-ot:is-link(.)">
          <xsl:apply-templates select="." mode="topicpull:add-gentext-PI"/>
          <!-- FIXME: need to avoid flattening complex markup here-->
          <xsl:value-of select="$linktext"/>
        </xsl:if>
        <xsl:if test="exists($linktext) and contains(@class, ' topic/link ')">
          <xsl:apply-templates select="." mode="topicpull:add-gentext-PI"/>
          <!-- FIXME: need to avoid flattening complex markup here-->
          <linktext class="- topic/linktext ">
            <xsl:value-of select="$linktext"/>
          </linktext>
        </xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:variable name="link-classes" as="xs:string*"
                select="(' topic/cite ',
                         ' topic/dt ',
                         ' topic/keyword ',
                         ' topic/term ',
                         ' topic/ph ',
                         ' topic/indexterm ',
                         ' topic/index-base ',
                         ' topic/indextermref ')"/>
  
  <!-- Called when retrieving text for a link or xref. Determine if the reference
       points to a topic, or to an element, and process accordingly. -->
  <xsl:template match="*" mode="topicpull:getlinktext">
    <xsl:param name="targetElement" as="element()"/>
    
    <xsl:variable name="resolvedLinkText" as="node()*">
      <xsl:apply-templates select="$targetElement" mode="topicpull:resolvelinktext">
        <xsl:with-param name="linkElement" as="element()" tunnel="yes" select="."/>
      </xsl:apply-templates>
    </xsl:variable>
    
    <xsl:choose>
      <xsl:when test="exists($resolvedLinkText)">
        <xsl:sequence select="$resolvedLinkText"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="starts-with(@href,'#')">
            <xsl:value-of select="@href"/>
          </xsl:when>
          <xsl:when test="empty(@format) or @format = 'dita'">
            <xsl:sequence select="()"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@href"/>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="." mode="ditamsg:cannot-retrieve-linktext"/>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>
  
  <!-- If a link is to a title, assume the parent is the real target, process accordingly -->
  <xsl:template match="*[contains(@class,' topic/title ')]" mode="topicpull:resolvelinktext">
    <xsl:apply-templates select=".." mode="topicpull:resolvelinktext"/>
  </xsl:template>
  
  <!-- Get the link text from a specific topic. -->
  <xsl:template match="*[contains(@class, ' topic/topic ')]" mode="topicpull:resolvelinktext">  
    
    <xsl:variable name="target-text" as="xs:string*">
      <xsl:apply-templates
        select="*[contains(@class, ' topic/title ')]" mode="text-only"/>
    </xsl:variable>
    <xsl:value-of select="normalize-space(string-join($target-text, ''))"/>    
  </xsl:template>
  
  <!-- Get link text for arbitrary block elements inside a topic. Assumes that the
       target element has a title element. -->
  <xsl:template match="*" mode="topicpull:resolvelinktext" priority="-1">
    <xsl:variable name="target-text"> 
      <xsl:choose>
        <xsl:when test="*[contains(@class,' topic/title ')][1]">
          <xsl:apply-templates
            select="*[contains(@class,' topic/title ')][1]" mode="text-only"/>
        </xsl:when>
        <!--If there isn't a title ,then process with spectitle -->
        <xsl:when test="@spectitle">
          <xsl:value-of select="@spectitle"/>
        </xsl:when>
        <!-- No title or spectitle; check to see if the element provides generated text -->
        <xsl:otherwise>
          <xsl:apply-templates select="." mode="topicpull:get_generated_text"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="exists($target-text)">
      <xsl:value-of select="normalize-space($target-text)"/>
    </xsl:if>    
  </xsl:template>
  
  <!-- Pull link text for a figure. Uses mode="topicpull:figure-linktext" to output the text.  -->
  <xsl:template match="*[contains(@class, ' topic/fig ')][*[contains(@class,' topic/title ')]]" mode="topicpull:resolvelinktext">
    
    <xsl:variable name="fig-count-actual">
      <xsl:apply-templates select="*[contains(@class,' topic/title ')][1]" mode="topicpull:fignumber"/>
    </xsl:variable>
    <xsl:apply-templates select="." mode="topicpull:figure-linktext">
      <xsl:with-param name="figtext">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Figure'"/>
        </xsl:call-template>
      </xsl:with-param>
      <xsl:with-param name="figcount" select="$fig-count-actual"/>
      <xsl:with-param name="figtitle">
        <xsl:sequence select="*[contains(@class,' topic/title ')][1]"/>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/fig ')][@spectitle]" mode="topicpull:resolvelinktext">
    
    <xsl:variable name="fig-count-actual">
      <xsl:apply-templates select="." mode="topicpull:fignumber"/>
    </xsl:variable>
    <xsl:apply-templates select="." mode="topicpull:figure-linktext">
      <xsl:with-param name="figtext"><xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Figure'"/></xsl:call-template></xsl:with-param>
      <xsl:with-param name="figcount" select="$fig-count-actual"/>
      <xsl:with-param name="figtitle" select="@spectitle" as="xs:string"/>
    </xsl:apply-templates>
  </xsl:template>
  
  
  <!-- Get the link text for a reference to a topic.  -->
  <xsl:template match="*" mode="topicpull:getlinktext_topic">
    <xsl:param name="targetElement" as="element()?"/>
    
    <xsl:choose>
      <xsl:when test="$targetElement/*[contains(@class, ' topic/title ')]">
        <xsl:variable name="target-text" as="xs:string*">
          <xsl:apply-templates
            select="$targetElement/*[contains(@class, ' topic/title ')]" mode="text-only"/>
        </xsl:variable>
        <xsl:value-of select="normalize-space(string-join($target-text, ''))"/>
      </xsl:when>
      <!-- if can't retrieve, don't create the linktext - defer to the final output process, which will massage the file name-->
      <xsl:otherwise>
        <xsl:sequence select="()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Provide a hook for specializations to give default generated text to new elements.
       By default, elements with no generated text return an empty sequence. -->
  <xsl:template match="*" mode="topicpull:get_generated_text">
    <xsl:sequence select="()"/>
  </xsl:template>

  <!--No link text found; use the href, unless it contains .dita, in which case defer to the final output pass to decide what to do with the file extension-->
  <xsl:template match="*" mode="topicpull:otherblock-linktext-fallback">
    <xsl:choose>
      <xsl:when test="starts-with(@href,'#')">
        <xsl:value-of select="@href"/>
      </xsl:when>
      <xsl:when test="empty(@format) or @format = 'dita'">
        <xsl:sequence select="()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="@href"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="." mode="ditamsg:cannot-retrieve-linktext"/>
  </xsl:template>

  <!-- Determine the text for a link to a figure. Currently uses "Figure N". A node set
       containing the figure's <title> element is also passed in, an override may choose
       to use this in the figure's reference text. -->
  <xsl:template match="*" mode="topicpull:figure-linktext">
    <xsl:param name="figtext"/>
    <xsl:param name="figcount"/>
    <xsl:param name="figtitle"/>
    <xsl:choose>
      <xsl:when test="$FIGURELINK='TITLE'">
        <xsl:apply-templates select="$figtitle" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise> <!-- Default: FIGURELINK='NUMBER' -->
        <xsl:value-of select="$figtext"/>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'figure-number-separator'"/>
        </xsl:call-template>
        <xsl:value-of select="$figcount"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- XXX: Remove I18N processing from here and move to transtype specific code -->
  <xsl:template match="*[lang('hu')]" mode="topicpull:figure-linktext">
    <!-- Hungarian: "1. Figure " -->
    <xsl:param name="figtext"/>
    <xsl:param name="figcount"/>
    <xsl:param name="figtitle"/> <!-- Currently unused, but may be picked up by an override -->
    <xsl:choose>
      <xsl:when test="$FIGURELINK='TITLE'">
        <xsl:apply-templates select="$figtitle" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise> <!-- Default: FIGURELINK='NUMBER' -->
        <xsl:value-of select="$figcount"/>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'figure-number-separator'"/>
        </xsl:call-template>
        <xsl:value-of select="$figtext"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- If the figure is unavailable or we're not sure what to do with it, generate fallback text -->
  <xsl:template match="*" mode="topicpull:figure-linktext-fallback">
    <xsl:choose>
      <xsl:when test="starts-with(@href,'#')">
        <xsl:value-of select="@href"/>
      </xsl:when>
      <xsl:when test="empty(@format) or @format = 'dita'">
        <xsl:sequence select="()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="@href"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="." mode="ditamsg:cannot-retrieve-linktext"/>
  </xsl:template>

  <!-- Determine the number of the figure being linked to -->
  <xsl:template match="*[contains(@class,' topic/fig ')]/*[contains(@class,' topic/title ')] | *[contains(@class,' topic/fig ')][@spectitle]" mode="topicpull:fignumber">
    <xsl:call-template name="compute-number">
      <xsl:with-param name="all">
        <xsl:number from="/*" count="key('count.topic.fig','include')" level="any"/>
      </xsl:with-param>
      <xsl:with-param name="except">
        <xsl:number from="/*" count="key('count.topic.fig','exclude')" level="any"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/table ')][*[contains(@class,' topic/title ')]]" mode="topicpull:resolvelinktext">
    <xsl:variable name="tbl-count-actual">
      <xsl:apply-templates select="*[contains(@class,' topic/title ')][1]" mode="topicpull:tblnumber"/>
    </xsl:variable>
    <xsl:apply-templates select="." mode="topicpull:table-linktext">
      <xsl:with-param name="tbltext"><xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Table'"/></xsl:call-template></xsl:with-param>
      <xsl:with-param name="tblcount" select="$tbl-count-actual"/>
      <xsl:with-param name="tbltitle" as="node()*">
        <xsl:sequence select="*[contains(@class,' topic/title ')][1]"/>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/table ')][@spectitle]" mode="topicpull:resolvelinktext">
    
    <xsl:variable name="tbl-count-actual">
      <xsl:apply-templates select="." mode="topicpull:tblnumber"/>
    </xsl:variable>
    <xsl:apply-templates select="." mode="topicpull:table-linktext">
      <xsl:with-param name="tbltext"><xsl:call-template name="getVariable"><xsl:with-param name="id" select="'Table'"/></xsl:call-template></xsl:with-param>
      <xsl:with-param name="tblcount" select="$tbl-count-actual"/>
      <xsl:with-param name="tbltitle" as="node()*" select="@spectitle"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Determine the text for a link to a table. Currently uses table title. -->
  <xsl:template match="*" mode="topicpull:table-linktext">
    <xsl:param name="tbltext"/>
    <xsl:param name="tblcount"/>
    <xsl:param name="tbltitle"/> <!-- Currently unused, but may be picked up by an override -->
    <xsl:choose>
      <xsl:when test="$TABLELINK='TITLE'">
        <xsl:apply-templates select="$tbltitle" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise> <!-- Default: TABLELINK='NUMBER' -->
        <xsl:value-of select="$tbltext"/>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'figure-number-separator'"/>
        </xsl:call-template>
        <xsl:value-of select="$tblcount"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*[lang('hu')]" mode="topicpull:table-linktext">
    <!-- Hungarian: "1. Table" -->
    <xsl:param name="tbltext"/>
    <xsl:param name="tblcount"/>
    <xsl:param name="tbltitle"/> <!-- Currently unused, but may be picked up by an override -->
    <xsl:choose>
      <xsl:when test="$TABLELINK='TITLE'">
        <xsl:apply-templates select="$tbltitle" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise> <!-- Default: TABLELINK='NUMBER' -->
        <xsl:value-of select="$tblcount"/>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'figure-number-separator'"/>
        </xsl:call-template>
        <xsl:value-of select="$tbltext"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- Fallback text if a table target cannot be found, or there is some other problem -->
  <xsl:template match="*" mode="topicpull:table-linktext-fallback">
    <xsl:choose>
      <xsl:when test="starts-with(@href,'#')">
        <xsl:value-of select="@href"/>
      </xsl:when>
      <xsl:when test="empty(@format) or @format = 'dita'">
        <xsl:sequence select="()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="@href"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="." mode="ditamsg:cannot-retrieve-linktext"/>
  </xsl:template>

  <!-- Determine the number of the table being linked to -->
  <xsl:template match="*[contains(@class,' topic/table ')]/*[contains(@class,' topic/title ')]  | *[contains(@class,' topic/table ')][@spectitle]" mode="topicpull:tblnumber">
    <xsl:call-template name="compute-number">
      <xsl:with-param name="all">
        <xsl:number from="/*" count="key('count.topic.table','include')" level="any"/>
      </xsl:with-param>
      <xsl:with-param name="except">
        <xsl:number from="/*" count="key('count.topic.table','exclude')" level="any"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:template>

  <!-- Set link text when linking to a list item in an ordered list -->
  <xsl:template mode="topicpull:resolvelinktext" priority="10" 
    match="*[contains(@class, ' topic/ol ')]/*[contains(@class, ' topic/li ')]" 
    >
    
    <xsl:apply-templates mode="topicpull:li-linktext" 
      select="."/>
  </xsl:template>  
  
  <xsl:template match="*[contains(@class, ' topic/li ')]" mode="topicpull:resolvelinktext">
    <xsl:param name="linkElement" as="element()" tunnel="yes"/>
    
    <xsl:for-each select="$linkElement">
      <xsl:call-template name="topicpull:referenced-invalid-list-item"/>
    </xsl:for-each>
  </xsl:template>
  
  <!-- Matching the list item, determine the count for this item -->
  <xsl:template match="*[contains(@class,' topic/ol ')]/*[contains(@class,' topic/li ')]" mode="topicpull:li-linktext">
    <xsl:number level="multiple"
      count="*[contains(@class,' topic/ol ')]/*[contains(@class,' topic/li ')]" format="1.a.i.1.a.i.1.a.i"/>
  </xsl:template>
  <!-- Instead of matching an unordered list item, we will call this template; that way
     the error points to the XREF, not to the list item. -->
  <xsl:template name="topicpull:referenced-invalid-list-item">
    <xsl:apply-templates select="." mode="ditamsg:crossref-unordered-listitem"/>
  </xsl:template>

  <!-- Generate link text for a footnote reference -->
  <xsl:template match="*[contains(@class,' topic/fn ')]" mode="topicpull:resolvelinktext">
    <xsl:apply-templates mode="topicpull:fn-linktext" 
      select="."/>
    
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/fn ')]" mode="topicpull:fn-linktext">
    <xsl:variable name="fnid">
      <xsl:number from="/" level="any"/>
    </xsl:variable>
    <xsl:variable name="callout" select="@callout" as="xs:string?"/>
    <xsl:variable name="convergedcallout">
      <xsl:choose>
        <xsl:when test="string-length($callout)&gt;0">
          <xsl:value-of select="$callout"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$fnid"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <a name="fnsrc_{$fnid}" href="#fntarg_{$fnid}">
      <sup>
        <xsl:value-of select="$convergedcallout"/>
      </sup>
    </a>
  </xsl:template>

  <!-- Getting text from a dlentry target: use the contents of the term -->
  <xsl:template match="*[contains(@class, ' topic/dlentry ')][*[contains(@class,' topic/dt ')]]"
    mode="topicpull:resolvelinktext">
    <xsl:variable name="target-text" as="xs:string*">
      <xsl:apply-templates
        select="*[contains(@class,' topic/dt ')][1]" mode="text-only"/>
    </xsl:variable>
    <xsl:value-of select="normalize-space(string-join($target-text, ''))"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/dt ')]" mode="topicpull:resolvelinktext">
    <xsl:apply-templates select="." mode="text-only"/>
  </xsl:template>
  
  <!--getting the shortdesc for a link; called from main mode template for link/xref, 
      only after conditions such as scope and format have been tested and a text pull
      has been determined to be appropriate-->
  <xsl:template match="*" mode="topicpull:getshortdesc">
    <xsl:param name="targetElement" as="element()?"/>
    <xsl:choose>
      <xsl:when test="not(dita-ot:is-topic($targetElement))">
        <xsl:apply-templates select="." mode="topicpull:getshortdesc_element">
          <xsl:with-param name="targetElement" as="element()?" select="$targetElement"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="topicpull:getshortdesc_topic">
          <xsl:with-param name="targetElement" as="element()?" select="$targetElement"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Get the short description for a non-topic element. Search for an element with the matching
       correct class value and matching ID, inside the topic with the correct ID. If found, use
       the local <desc> element. If not found, do not create a short description. -->
  <xsl:template match="*" mode="topicpull:getshortdesc_element">
    <xsl:param name="targetElement" as="element()?"/>

    <xsl:choose>
      <xsl:when test="$targetElement/*[contains(@class, ' topic/desc ')]">
        <xsl:apply-templates select="$targetElement/*[contains(@class, ' topic/desc ')]" mode="copy-desc-contents"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Get the shortdesc from a specific topic in another file -->
  <xsl:template match="*" mode="topicpull:getshortdesc_topic">
    <xsl:param name="targetElement" as="element()?"/>
    <xsl:choose>
      <xsl:when test="$targetElement/*[contains(@class, ' topic/shortdesc ')] |
                      $targetElement/*[contains(@class, ' topic/abstract ')]/*[contains(@class, ' topic/shortdesc ')]">
        <xsl:apply-templates select="$targetElement/*[contains(@class, ' topic/shortdesc ')] | 
                                     $targetElement/*[contains(@class, ' topic/abstract ')]/*[contains(@class, ' topic/shortdesc ')]" mode="copy-shortdesc"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*|text()|processing-instruction()" mode="text-only">
    <!-- Redirect to common dita-ot module -->
    <xsl:apply-templates select="." mode="dita-ot:text-only"/>
  </xsl:template>
  <xsl:template match="*|@*|comment()|processing-instruction()|text()">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|comment()|processing-instruction()|text()"/>
    </xsl:copy>
  </xsl:template>
  
  
  <xsl:template match="*[contains(@class,' topic/xref ')]" mode="copy-shortdesc">
    <xsl:choose>
      <xsl:when test="empty(@href) or @scope='peer' or @scope='external'">
        <xsl:copy>
          <xsl:apply-templates select="@*|text()|*" mode="copy-shortdesc" />
        </xsl:copy>
      </xsl:when>
      <xsl:when test="@format and not(@format='dita')">
        <xsl:copy>
          <xsl:apply-templates select="@*|text()|*" mode="copy-shortdesc" />
        </xsl:copy>
      </xsl:when>
      <xsl:when test="not(contains(@href,'/'))"><!-- May be DITA, but in the same directory -->
        <xsl:copy>
          <xsl:apply-templates select="@*|text()|*" mode="copy-shortdesc" />
        </xsl:copy>
      </xsl:when>
      <xsl:when test="text()|*[not(contains(@class,' topic/desc '))]">
        <xsl:apply-templates select="*[not(contains(@class,' topic/desc '))]|text()|comment()|processing-instruction()" mode="copy-shortdesc" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>***</xsl:text><!-- go get the target text -->
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="text()" mode="copy-shortdesc">
    <xsl:value-of select="translate(.,'&#xA;',' ')" />
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' topic/desc ')]" mode="copy-desc-contents">
    <!-- For desc: match a desc, then switch to matching shortdesc rules -->
    <xsl:apply-templates select="*|text()|comment()|processing-instruction()" mode="copy-shortdesc"/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' topic/shortdesc ')]" mode="copy-shortdesc">
    <xsl:if test="preceding-sibling::*[contains(@class,' topic/shortdesc ')]">
      <!-- In an abstract, and this is not the first -->
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:apply-templates select="*|text()|comment()|processing-instruction()" mode="copy-shortdesc" />
  </xsl:template>
  
  <xsl:template match="@id" mode="copy-shortdesc" />
  
  <xsl:template match="*[contains(@class,' topic/indexterm ')]" mode="copy-shortdesc" />
  <xsl:template match="*[contains(@class,' topic/draft-comment ') or contains(@class,' topic/required-cleanup ')]" mode="copy-shortdesc"/>
  
  <xsl:template match="*|@*|processing-instruction()" mode="copy-shortdesc">
    <xsl:copy>
      <xsl:apply-templates select="@*|text()|*|processing-instruction()" mode="copy-shortdesc" />
    </xsl:copy>
  </xsl:template>

  <!-- Used to determine the number of figures and tables; could be used for other functions as well. -->
  <xsl:template name="compute-number">
    <xsl:param name="except"/>
    <xsl:param name="all"/>
    <xsl:choose>
      <xsl:when test="$except != ''">
        <xsl:value-of select="number($all) - number($except)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$all"/>
      </xsl:otherwise>
    </xsl:choose>
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
  <xsl:template match="*" mode="ditamsg:empty-href">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX017E'"/>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:missing-href">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX028E'"/>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:type-attribute-not-specific">
    <xsl:param name="elem-name" select="name()"/>
    <xsl:param name="targetting"/>
    <xsl:param name="type"/>
    <xsl:param name="actual-name"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX029I'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$elem-name"/>;%2=<xsl:value-of select="$targetting"/>;%3=<xsl:value-of select="$type"/>;%4=<xsl:value-of select="$actual-name"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:type-attribute-incorrect">
    <xsl:param name="elem-name" select="name()"/>
    <xsl:param name="targetting"/>
    <xsl:param name="type"/>
    <xsl:param name="actual-name"/>
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX030W'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="$elem-name"/>;%2=<xsl:value-of select="$targetting"/>;%3=<xsl:value-of select="$type"/>;%4=<xsl:value-of select="$actual-name"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:missing-href-target">
    <xsl:param name="file"/>
    <xsl:choose>
       <xsl:when test="$ONLYTOPICINMAP='true'">
          <xsl:call-template name="output-message">
             <xsl:with-param name="id" select="'DOTX056W'"/>
             <xsl:with-param name="msgparams">%1=<xsl:value-of select="$file"/></xsl:with-param>
           </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
         <xsl:call-template name="output-message">
            <xsl:with-param name="id" select="'DOTX031E'"/>
            <xsl:with-param name="msgparams">%1=<xsl:value-of select="$file"/></xsl:with-param>
            </xsl:call-template>
         </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:cannot-retrieve-linktext">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX032E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:cannot-retrieve-list-number">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX033E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:crossref-unordered-listitem">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX034E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:cannot-retrieve-footnote-number">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX035E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="*" mode="ditamsg:cannot-find-dlentry-target">
    <xsl:call-template name="output-message">
      <xsl:with-param name="id" select="'DOTX036E'"/>
      <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="*|@*|text()|comment()|processing-instruction()" mode="specialize-foreign-unknown">
    <xsl:copy>
      <xsl:apply-templates select="*|@*|comment()|processing-instruction()|text()" mode="specialize-foreign-unknown"/>
    </xsl:copy>
  </xsl:template>

  <!-- Added for RFE 1367897. Ensure that if a value was passed in from the map,
       we respect that value, otherwise, use the value determined by this program. -->
  <xsl:template match="*" mode="topicpull:add-gentext-PI">
    <xsl:choose>
      <xsl:when test="processing-instruction()[name()='ditaot'][.='usertext' or .='gentext']">
        <xsl:copy-of select="processing-instruction()[name()='ditaot'][.='usertext' or .='gentext']"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:processing-instruction name="ditaot">gentext</xsl:processing-instruction>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*" mode="topicpull:add-usertext-PI">
    <xsl:choose>
      <xsl:when test="processing-instruction()[name()='ditaot'][.='usertext' or .='gentext']">
        <xsl:copy-of select="processing-instruction()[name()='ditaot'][.='usertext' or .='gentext']"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:processing-instruction name="ditaot">usertext</xsl:processing-instruction>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Added for RFE 3001750. -->
  <xsl:template match="*" mode="topicpull:add-genshortdesc-PI">
    <xsl:choose>
      <xsl:when test="processing-instruction()[name()='ditaot'][.='usershortdesc' or .='genshortdesc']">
        <xsl:copy-of select="processing-instruction()[name()='ditaot'][.='usershortdesc' or .='genshortdesc']"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:processing-instruction name="ditaot">genshortdesc</xsl:processing-instruction>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="*" mode="topicpull:add-usershortdesc-PI">
    <xsl:choose>
      <xsl:when test="processing-instruction()[name()='ditaot'][.='usershortdesc' or .='genshortdesc']">
        <xsl:copy-of select="processing-instruction()[name()='ditaot'][.='usershortdesc' or .='genshortdesc']"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:processing-instruction name="ditaot">usershortdesc</xsl:processing-instruction>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
