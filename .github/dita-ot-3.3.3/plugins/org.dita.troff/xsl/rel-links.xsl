<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
  xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
  exclude-result-prefixes="related-links ditamsg">

<xsl:key name="link" match="*[contains(@class, ' topic/link ')][not(ancestor::*[contains(@class, ' topic/linklist ')])]" use="concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' ')))"/>
<xsl:key name="linkdup" match="*[contains(@class, ' topic/link ')][not(ancestor::*[contains(@class, ' topic/linklist ')])][not(@role='child' or @role='parent' or @role='previous' or @role='next' or @role='ancestor' or @role='descendant')]" use="concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href)"/>
<xsl:key name="hideduplicates" match="*[contains(@class, ' topic/link ')][not(ancestor::*[contains(@class, ' topic/linklist ')])][not(@role) or @role='cousin' or @role='external' or @role='friend' or @role='other' or @role='sample' or @role='sibling']" use="concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ',@href,@scope,@audience,@platform,@product,@otherprops,@rev,@type, normalize-space(string-join(*, ' ')))"/>

<xsl:param name="NOPARENTLINK" select="'no'"/><!-- "no" and "yes" are valid values; non-'no' is ignored -->

<!-- ========== Hooks for common user customizations ============== -->
<!-- The following two templates are available for anybody who needs
     to put out an token at the start or end of a link, such as an
     icon to indicate links to PDF files or external web addresses. -->
<xsl:template match="*" mode="add-link-highlight-at-start"/>
<xsl:template match="*" mode="add-link-highlight-at-end"/>
<xsl:template match="*" mode="add-xref-highlight-at-start"/>
<xsl:template match="*" mode="add-xref-highlight-at-end"/>

<!-- Override this template to add any standard link attributes.
     Called for all links. -->
<xsl:template match="*" mode="add-custom-link-attributes"/>

<!-- Override these templates to place some a prefix before generated
     child links, such as "Optional" for optional child links. Called
     for all child links. -->
<xsl:template match="*" mode="related-links:ordered.child.prefix"/>
<xsl:template match="*" mode="related-links:unordered.child.prefix"/>

<!-- ========== End hooks for common user customizations ========== -->

<!--template for xref-->
<xsl:template match="*[contains(@class,' topic/xref ')]" name="topic.xref">
  <xsl:choose>
    <xsl:when test="@href and normalize-space(@href)!=''">
      <xsl:apply-templates select="." mode="add-xref-highlight-at-start"/>
      <a>
        <xsl:apply-templates select="." mode="add-linking-attributes"/>
        <xsl:apply-templates select="." mode="add-desc-as-hoverhelp"/>
        <!-- if there is text or sub element other than desc, apply templates to them
          otherwise, use the href as the value of link text. -->
        <xsl:choose>
          <xsl:when test="@type='fn'">
            <sup>
              <xsl:choose>
                <xsl:when test="*[not(contains(@class,' topic/desc '))]|text()">
                  <xsl:apply-templates select="*[not(contains(@class,' topic/desc '))]|text()"/>
                  <!--use xref content-->
                </xsl:when>
                <xsl:otherwise>
                  <xsl:call-template name="href"/><!--use href text-->
                </xsl:otherwise>
              </xsl:choose>
            </sup>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="*[not(contains(@class,' topic/desc '))]|text()">
                <xsl:apply-templates select="*[not(contains(@class,' topic/desc '))]|text()"/>
                <!--use xref content-->
              </xsl:when>
              <xsl:otherwise>
                <xsl:call-template name="href"/><!--use href text-->
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>        
      </a>
      <xsl:apply-templates select="." mode="add-xref-highlight-at-end"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="*|text()|comment()|processing-instruction()"/>
    </xsl:otherwise>
  </xsl:choose>
    
</xsl:template>

<!--create breadcrumbs for each grouping of ancestor links; include previous, next, and ancestor links, sorted by linkpool/related-links parent. If there is more than one linkpool that contains ancestors, multiple breadcrumb trails will be generated-->
<xsl:template match="*[contains(@class,' topic/related-links ')]" mode="breadcrumb">
  <xsl:for-each select="descendant-or-self::*[contains(@class,' topic/related-links ') or contains(@class,' topic/linkpool ')][child::*[@role='ancestor']]">
     <xsl:value-of select="$newline"/><div class="breadcrumb">
     <xsl:choose>
          <!--output previous link first, if it exists-->
          <xsl:when test="*[@href][@role='previous']">
               <xsl:apply-templates select="*[@href][@role='previous'][1]" mode="breadcrumb"/>
          </xsl:when>
          <xsl:otherwise/>
     </xsl:choose>
     <!--if both previous and next links exist, output a separator bar-->
     <xsl:if test="*[@href][@role='next'] and *[@href][@role='previous']">
       <xsl:text> | </xsl:text>
     </xsl:if>
     <xsl:choose>
          <!--output next link, if it exists-->
          <xsl:when test="*[@href][@role='next']">
               <xsl:apply-templates select="*[@href][@role='next'][1]" mode="breadcrumb"/>
          </xsl:when>
          <xsl:otherwise/>
     </xsl:choose>
     <!--if we have either next or previous, plus ancestors, separate the next/prev from the ancestors with a vertical bar-->
     <xsl:if test="(*[@href][@role='next'] or *[@href][@role='previous']) and *[@href][@role='ancestor']">
       <xsl:text> | </xsl:text>
     </xsl:if>
     <!--if ancestors exist, output them, and include a greater-than symbol after each one, including a trailing one-->
     <xsl:if test="*[@href][@role='ancestor']">
     <xsl:for-each select="*[@href][@role='ancestor']">
               <xsl:apply-templates select="."/> &gt;
     </xsl:for-each>
     </xsl:if>
     </div><xsl:value-of select="$newline"/>
  </xsl:for-each>
</xsl:template>

<!--create prerequisite links with all dups eliminated. -->
<xsl:template match="*[contains(@class,' topic/related-links ')]" mode="prereqs">

  <!--if there are any prereqs create a list with dups-->
  <xsl:if test="descendant::*[contains(@class, ' topic/link ')][not(ancestor::*[contains(@class, ' topic/linklist ')])][@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='previous' or @role='cousin')]">
     <xsl:value-of select="$newline"/><dl class="prereqlinks"><xsl:value-of select="$newline"/>
     <dt class="prereq">
             <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Prerequisites'"/>
               </xsl:call-template>
     </dt><xsl:value-of select="$newline"/>
     <!--only create link if there is an href, its importance is required, and the role is compatible (don't want a prereq showing up for a "next" or "parent" link, for example) - remove dups-->
     <xsl:apply-templates mode="prereqs" select="descendant::*[generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])]
     [@href]
     [@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='previous' or @role='cousin')]
     [not(ancestor::*[contains(@class, ' topic/linklist ')])]"/>
      </dl><xsl:value-of select="$newline"/>
  </xsl:if>

</xsl:template>

<!-- Omit prereq links from unordered related-links (handled by mode="prereqs" template). -->
<xsl:key name="omit-from-unordered-links" match="*[@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='cousin')]" use="1"/>

<!--main template for setting up all links after the body - applied to the related-links container-->
<xsl:template match="*[contains(@class,' topic/related-links ')]" name="topic.related-links">
 <div>
  <xsl:call-template name="ul-child-links"/><!--handle child/descendants outside of linklists in collection-type=unordered or choice-->

  <xsl:call-template name="ol-child-links"/><!--handle child/descendants outside of linklists in collection-type=ordered/sequence-->

  <xsl:call-template name="next-prev-parent-links"/><!--handle next and previous links-->

  <!-- Calls to typed links deprecated.  Grouping instead performed by related-links:group-unordered-links template. -->

  <!--<xsl:call-template name="concept-links"/>--><!--sort remaining concept links by type-->

  <!--<xsl:call-template name="task-links"/>--><!--sort remaining task links by type-->

  <!--<xsl:call-template name="reference-links"/>--><!--sort remaining reference links by type-->

  <!--<xsl:call-template name="relinfo-links"/>--><!--handle remaining untyped and unknown-type links-->

  <!-- Group all unordered links (which have not already been handled by prior sections). Skip duplicate links. -->
  <!-- NOTE: The actual grouping code for related-links:group-unordered-links is common between
             transform types, and is located in ../common/related-links.xsl. Actual code for
             creating group titles and formatting links is located in XSL files specific to each type. -->
 <xsl:apply-templates select="." mode="related-links:group-unordered-links">
     <xsl:with-param name="nodes" select="descendant::*[contains(@class, ' topic/link ')]
       [count(. | key('omit-from-unordered-links', 1)) != count(key('omit-from-unordered-links', 1))]
       [generate-id(.)=generate-id((key('hideduplicates', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ',@href,@scope,@audience,@platform,@product,@otherprops,@rev,@type, normalize-space(string-join(*, ' ')))))[1])]"/>
 </xsl:apply-templates>  

  <!--linklists - last but not least, create all the linklists and their links, with no sorting or re-ordering-->
  <xsl:apply-templates select="*[contains(@class,' topic/linklist ')]"/>
 </div>
</xsl:template>


<!--children links - handle all child or descendant links except those in linklists or ordered collection-types.
Each child is indented, the linktext is bold, and the shortdesc appears in normal text directly below the link, to create a summary-like appearance.-->
<xsl:template name="ul-child-links">
     <xsl:if test="descendant::*[contains(@class, ' topic/link ')][@role='child' or @role='descendant'][not(parent::*/@collection-type='sequence')][not(ancestor::*[contains(@class, ' topic/linklist ')])]">
     <xsl:value-of select="$newline"/><ul class="ullinks"><xsl:value-of select="$newline"/>
       <!--once you've tested that at least one child/descendant exists, apply templates to only the unique ones-->
          <xsl:apply-templates select="descendant::*
          [generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])]
          [contains(@class, ' topic/link ')]
          [@role='child' or @role='descendant']
          [not(parent::*/@collection-type='sequence')]
          [not(ancestor::*[contains(@class, ' topic/linklist ')])]"/>
     </ul><xsl:value-of select="$newline"/>
     </xsl:if>
</xsl:template>

<!--children links - handle all child or descendant links in ordered collection-types.
Children are displayed in a numbered list, with the target title as the cmd and the shortdesc as info, like a task.
-->
<xsl:template name="ol-child-links">
     <xsl:if test="descendant::*[contains(@class, ' topic/link ')][@role='child' or @role='descendant'][parent::*/@collection-type='sequence'][not(ancestor::*[contains(@class, ' topic/linklist ')])]">
     <xsl:value-of select="$newline"/><ol class="olchildlinks"><xsl:value-of select="$newline"/>
       <!--once you've tested that at least one child/descendant exists, apply templates to only the unique ones-->
          <xsl:apply-templates select="descendant::*
          [generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])]
          [contains(@class, ' topic/link ')]
          [@role='child' or @role='descendant']
          [parent::*/@collection-type='sequence']
          [not(ancestor-or-self::*[contains(@class, ' topic/linklist ')])]"/>
     </ol><xsl:value-of select="$newline"/>
     </xsl:if>
</xsl:template>

<!-- Omit child and descendant links from unordered related-links (handled by ul-child-links and ol-child-links). -->
<xsl:key name="omit-from-unordered-links" match="*[@role='child']" use="1"/>
<xsl:key name="omit-from-unordered-links" match="*[@role='descendant']" use="1"/>

<!--create the next and previous links, with accompanying parent link if any; create group for each unique parent, as well as for any next and previous links that aren't in the same group as a parent-->
<xsl:template name="next-prev-parent-links">
     <xsl:for-each select="descendant::*
     [contains(@class, ' topic/link ')]
     [(@role='parent' and
          generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])
     ) or (@role='next' and
          generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])
     ) or (@role='previous' and
          generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])
     )]/parent::*">
     <xsl:value-of select="$newline"/><div class="familylinks"><xsl:value-of select="$newline"/>

    <xsl:if test="$NOPARENTLINK='no'"> 
     <xsl:choose>
       <xsl:when test="*[@href][@role='parent']">
         <xsl:for-each select="*[@href][@role='parent']">
          <div class="parentlink"><xsl:apply-templates select="."/></div><xsl:value-of select="$newline"/>
         </xsl:for-each>
       </xsl:when>
       <xsl:otherwise>
          <xsl:for-each select="*[@href][@role='ancestor'][last()]">
          <div class="parentlink"><xsl:call-template name="parentlink"/></div><xsl:value-of select="$newline"/>
          </xsl:for-each>
       </xsl:otherwise>
     </xsl:choose>
    </xsl:if>

     <xsl:for-each select="*[@href][@role='previous']">
          <div class="previouslink"><xsl:apply-templates select="."/></div><xsl:value-of select="$newline"/>
     </xsl:for-each>
     <xsl:for-each select="*[@href][@role='next']">
          <div class="nextlink"><xsl:apply-templates select="."/></div><xsl:value-of select="$newline"/>
     </xsl:for-each>
       </div><xsl:value-of select="$newline"/>
     </xsl:for-each>
</xsl:template>

<!-- Omit child and descendant links from unordered related-links (handled by next-prev-parent-links). -->
<xsl:key name="omit-from-unordered-links" match="*[@role='next']" use="1"/>
<xsl:key name="omit-from-unordered-links" match="*[@role='previous']" use="1"/>
<xsl:key name="omit-from-unordered-links" match="*[@role='parent']" use="1"/>
  
<!--type templates: concept, task, reference, relinfo-->
<!-- Deprecated! Use related-links:group-unordered-links template instead. -->

<xsl:template name="concept-links">
     <!-- Deprecated! Use related-links:group-unordered-links template instead. -->
     <!--related concepts - all the related concept links that haven't already been covered as a child/descendant/ancestor/next/previous/prerequisite, and aren't in a linklist-->
     <xsl:if test="descendant::*[contains(@class, ' topic/link ')]
          [not(ancestor::*[contains(@class,' topic/linklist ')])]
          [not(@role='child' or @role='descendant' or @role='ancestor' or @role='parent' or @role='next' or @role='previous')]
          [not(@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='cousin'))]
          [@type='concept']">
          <div class="relconcepts">
          <strong>
             <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Related concepts'"/>
               </xsl:call-template>
          </strong><br/><xsl:value-of select="$newline"/>
     <!--once the related concepts section is set up, sort links by role within the section, using a shared sorting routine so that it's consistent across sections-->
       <xsl:call-template name="sort-links-by-role"><xsl:with-param name="type">concept</xsl:with-param></xsl:call-template>
          </div><xsl:value-of select="$newline"/>
     </xsl:if>
</xsl:template>

<xsl:template name="task-links">
     <!-- Deprecated! Use related-links:group-unordered-links template instead. -->
     <!--related tasks - all the related task links that haven't already been covered as a child/descendant/ancestor/next/previous/prerequisite, and aren't in a linklist-->
     <xsl:if test="descendant::*[contains(@class, ' topic/link ')]
          [not(ancestor::*[contains(@class,' topic/linklist ')])]
          [not(@role='child' or @role='descendant' or @role='ancestor' or @role='parent' or @role='next' or @role='previous')]
          [not(@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='cousin'))]
          [@type='task']">
          <div class="reltasks">
          <strong>
             <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Related tasks'"/>
               </xsl:call-template>
          </strong><br/><xsl:value-of select="$newline"/>
     <!--once the related tasks section is set up, sort links by role within the section, using a shared sorting routine so that it's consistent across sections-->
       <xsl:call-template name="sort-links-by-role"><xsl:with-param name="type">task</xsl:with-param></xsl:call-template>
          </div><xsl:value-of select="$newline"/>
     </xsl:if>
</xsl:template>


<xsl:template name="reference-links">
     <!-- Deprecated! Use related-links:group-unordered-links template instead. -->
     <!--related reference - all the related reference links that haven't already been covered as a child/descendant/ancestor/next/previous/prerequisite, and aren't in a linklist-->
     <xsl:if test="descendant::*
          [contains(@class, ' topic/link ')]
          [not(ancestor::*[contains(@class,' topic/linklist ')])]
          [not(@role='child' or @role='descendant' or @role='ancestor' or @role='parent' or @role='next' or @role='previous')]
          [not(@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='cousin'))]
          [@type='reference']">
          <div class="relref">
          <strong>
             <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Related reference'"/>
               </xsl:call-template>
          </strong><br/><xsl:value-of select="$newline"/>
     <!--once the related reference section is set up, sort links by role within the section, using a shared sorting routine so that it's consistent across sections-->
       <xsl:call-template name="sort-links-by-role"><xsl:with-param name="type">reference</xsl:with-param></xsl:call-template>
          </div><xsl:value-of select="$newline"/>
     </xsl:if>
</xsl:template>


<xsl:template name="relinfo-links">
     <!-- Deprecated! Use related-links:group-unordered-links template instead. -->
     <!--other info- - not currently sorting by role, since already mixing any number of types in here-->
     <!--if there are links not covered by any of the other routines - ie, not in a linklist, not a child or descendant, not a concept/task/reference, not ancestor/next/previous, not prerequisite - create a section for them and create the links-->
     <xsl:if test="descendant::*
[contains(@class, ' topic/link ')]
[not(ancestor::*[contains(@class,' topic/linklist ')])]
          [not(@role='child' or @role='descendant' or @role='ancestor' or @role='parent' or @role='next' or @role='previous' or @type='concept' or @type='task' or @type='reference')]
          [not(@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='cousin'))]">
          <div class="relinfo">
          <strong>
             <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Related information'"/>
               </xsl:call-template>
          </strong><br/><xsl:value-of select="$newline"/>
       <!--once section is created, create the links, using the same rules as bove plus a uniqueness check-->
       <xsl:for-each select="descendant::*
          [not(ancestor::*[contains(@class,' topic/linklist ')])]
          [generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])]
[contains(@class, ' topic/link ')]
          [not(@role='child' or @role='descendant' or @role='ancestor' or @role='parent' or @role='next' or @role='previous' or @type='concept' or @type='task' or @type='reference')]
          [not(@importance='required' and (not(@role) or @role='sibling' or @role='friend' or @role='cousin'))]">
          <xsl:apply-templates select="."/>
       </xsl:for-each>
          </div><xsl:value-of select="$newline"/>
     </xsl:if>
</xsl:template>


<!--template used within concept/task/reference sections to sort links-->
<xsl:template name="sort-links-by-role">
  <!-- Deprecated! Use related-links:group-unordered-links template instead. -->
   <xsl:param name="type">topic</xsl:param>
     <!--create all sibling links of the specified type-->
     <xsl:call-template name="create-links"><xsl:with-param name="role">sibling</xsl:with-param><xsl:with-param name="type"><xsl:value-of select="$type"/></xsl:with-param></xsl:call-template>
     <!--create all cousin links of the specified type-->
     <xsl:call-template name="create-links"><xsl:with-param name="role">cousin</xsl:with-param><xsl:with-param name="type"><xsl:value-of select="$type"/></xsl:with-param></xsl:call-template>
     <!--create all friend links of the specified type-->
     <xsl:call-template name="create-links"><xsl:with-param name="role">friend</xsl:with-param><xsl:with-param name="type"><xsl:value-of select="$type"/></xsl:with-param></xsl:call-template>
     <!--create all links with role="other" of the specified type-->
     <xsl:call-template name="create-links"><xsl:with-param name="role">other</xsl:with-param><xsl:with-param name="type"><xsl:value-of select="$type"/></xsl:with-param></xsl:call-template>
        <!--create all links with no role of the specified type-->
     <xsl:call-template name="create-links"><xsl:with-param name="role">#none#</xsl:with-param><xsl:with-param name="type"><xsl:value-of select="$type"/></xsl:with-param></xsl:call-template>
</xsl:template>

<xsl:template name="create-links">
     <!-- Deprecated! Use related-links:group-unordered-links template instead. -->
     <!--create links of the specified type and role-->
     <xsl:param name="type">topic</xsl:param>
     <xsl:param name="role">friend</xsl:param>

       <xsl:choose>
          <!--when processing links with no role, apply templates to links that are unique, not in a linklist, don't have a role attribute, match the specified type, and aren't prerequisites-->
          <xsl:when test="$role='#none#'">
               <xsl:for-each select="descendant::*
               [generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])]
               [contains(@class, ' topic/link ')]
               [not(ancestor::*[contains(@class,' topic/linklist ')])]
               [not(@role)]
               [@type=$type]
               [not(@importance='required')]">
               <xsl:apply-templates select="."/>
          </xsl:for-each>
          </xsl:when>
          <!--when processing links with a specified role, apply templates to links that are unique, not in a linklist, match the specified role and type, and aren't prerequisites-->
          <xsl:otherwise>
                <xsl:for-each select="descendant::*
               [generate-id(.)=generate-id(key('link',concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[1])]
               [not(ancestor::*[contains(@class,' topic/linklist ')])]
               [contains(@class, ' topic/link ')]
               [@role=$role]
               [@type=$type]
               [not(@importance='required' and (@role='sibling' or @role='friend' or @role='previous' or @role='cousin'))]">
               <xsl:apply-templates select="."/>
                </xsl:for-each>

          </xsl:otherwise>
     </xsl:choose>
</xsl:template>

<!-- Override no-name group wrapper template for HTML: output "Related Information" in a <div>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:result-group" name="related-links:group-result.">
    <xsl:param name="links"/>
    <div class="relinfo">
      <strong>
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Related information'"/>
        </xsl:call-template>
      </strong><br/><xsl:value-of select="$newline"/>
      <xsl:copy-of select="$links"/>
    </div><xsl:value-of select="$newline"/>
  </xsl:template>
  
  <!-- Links with @type="topic" belong in no-name group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='topic']" mode="related-links:get-group-priority" name="related-links:group-priority.topic" priority="2">
    <xsl:call-template name="related-links:group-priority."></xsl:call-template>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='topic']" mode="related-links:get-group" name="related-links:group.topic" priority="2">
    <xsl:call-template name="related-links:group."></xsl:call-template>
  </xsl:template>
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='topic']" mode="related-links:result-group" name="related-links:group-result.topic" priority="2">
    <xsl:param name="links"/>
    <xsl:call-template name="related-links:group-result.">
      <xsl:with-param name="links" select="$links"></xsl:with-param>
    </xsl:call-template>    
  </xsl:template>
  
  
<!--calculate href-->
<xsl:template name="href">
  <xsl:apply-templates select="." mode="determine-final-href"/>
</xsl:template>
<xsl:template match="*" mode="determine-final-href">
  <xsl:choose>
    <xsl:when test="normalize-space(@href)='' or not(@href)"/>
    <!-- For non-DITA formats - use the href as is -->
    <xsl:when test="(not(@format) and (@type='external' or @scope='external')) or (@format and not(@format='dita'))">
      <xsl:value-of select="@href"/>
    </xsl:when>
    <!-- For DITA - process the internal href -->
    <xsl:when test="starts-with(@href,'#')">
      <xsl:call-template name="parsehref">
        <xsl:with-param name="href" select="@href"/>
      </xsl:call-template>
    </xsl:when>
    <!-- It's to a DITA file - process the file name (adding the html extension)
    and process the rest of the href -->
    <xsl:when test="(not(@scope) or @scope='local' or @scope='peer') and (not(@format) or @format='dita')">
      <xsl:call-template name="replace-extension">
        <xsl:with-param name="filename" select="@href"/>
        <xsl:with-param name="extension" select="$OUTEXT"/>
        <xsl:with-param name="ignore-fragment" select="true()"/>
      </xsl:call-template>
      <xsl:if test="contains(@href, '#')">
        <xsl:text>#</xsl:text>
        <xsl:call-template name="parsehref">
          <xsl:with-param name="href" select="substring-after(@href, '#')"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates select="." mode="ditamsg:unknown-extension"/>
      <xsl:value-of select="@href"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- "/" is not legal in IDs - need to swap it with two underscores -->
<xsl:template name="parsehref">
 <xsl:param name="href"/>
  <xsl:choose>
   <xsl:when test="contains($href,'/')">
    <xsl:value-of select="substring-before($href,'/')"/>__<xsl:value-of select="substring-after($href,'/')"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$href"/>
   </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--breadcrumb template: next, prev-->
<xsl:template match="*[contains(@class, ' topic/link ')][@role='next' or @role='previous']" mode="breadcrumb">
          <a>
             <xsl:apply-templates select="." mode="add-linking-attributes"/>
             <xsl:apply-templates select="." mode="add-title-as-hoverhelp"/>

             <!-- Allow for unknown metadata (future-proofing) -->
             <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>

          <!--use string as output link text for now, use image eventually-->
          <xsl:choose>
          <xsl:when test="@role='next'">
               <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Next topic'"/>
                    </xsl:call-template>
          </xsl:when>
          <xsl:when test="@role='previous'">
               <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Previous topic'"/>
                    </xsl:call-template>
          </xsl:when>
          <xsl:otherwise><!--both role values tested - no otherwise--></xsl:otherwise>
          </xsl:choose>
       </a>
</xsl:template>

<!--prereq template-->

<xsl:template mode="prereqs" match="*[contains(@class, ' topic/link ')]" priority="2">
          <dd>
            <!-- Allow for unknown metadata (future-proofing) -->
            <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>
            <xsl:call-template name="makelink"/>
          </dd><xsl:value-of select="$newline"/>
</xsl:template>



<!--plain templates: next, prev, ancestor/parent, children, everything else-->

<xsl:template name="nextlink" match="*[contains(@class, ' topic/link ')][@role='next']" priority="2">
          <strong>
            <!-- Allow for unknown metadata (future-proofing) -->
            <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>
          <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Next topic'"/>
               </xsl:call-template>
          <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'ColonSymbol'"/>
               </xsl:call-template>
          </strong><xsl:text> </xsl:text>
          <xsl:call-template name="makelink"/>
</xsl:template>

<xsl:template name="prevlink" match="*[contains(@class, ' topic/link ')][@role='previous']" priority="2">
          <strong>
            <!-- Allow for unknown metadata (future-proofing) -->
            <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>
          <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Previous topic'"/>
               </xsl:call-template>
          <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'ColonSymbol'"/>
               </xsl:call-template>
          </strong><xsl:text> </xsl:text>
          <xsl:call-template name="makelink"/>
</xsl:template>

<xsl:template name="parentlink" match="*[contains(@class, ' topic/link ')][@role='parent']" priority="2">
          <strong>
            <!-- Allow for unknown metadata (future-proofing) -->
            <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>
          <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'Parent topic'"/>
               </xsl:call-template>
          <xsl:call-template name="getVariable">
                  <xsl:with-param name="id" select="'ColonSymbol'"/>
               </xsl:call-template>
          </strong><xsl:text> </xsl:text>
          <xsl:call-template name="makelink"/>
</xsl:template>

<!--basic child processing-->
<xsl:template match="*[contains(@class, ' topic/link ')][@role='child' or @role='descendant']" priority="2" name="topic.link_child">
   <xsl:variable name="el-name">
       <xsl:choose>
           <xsl:when test="contains(../@class,' topic/linklist ')">div</xsl:when>
           <xsl:otherwise>li</xsl:otherwise>
       </xsl:choose>
   </xsl:variable>
   <xsl:element name="{$el-name}">
       <xsl:attribute name="class">ulchildlink</xsl:attribute>
       <!-- Allow for unknown metadata (future-proofing) -->
       <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>
     <strong>
     <xsl:apply-templates select="." mode="related-links:unordered.child.prefix"/>
     <xsl:apply-templates select="." mode="add-link-highlight-at-start"/>
     <a>
       <xsl:apply-templates select="." mode="add-linking-attributes"/>
       <xsl:apply-templates select="." mode="add-hoverhelp-to-child-links"/>

          <!--use linktext as linktext if it exists, otherwise use href as linktext-->
          <xsl:choose>
          <xsl:when test="*[contains(@class, ' topic/linktext ')]"><xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/></xsl:when>
          <xsl:otherwise><!--use href--><xsl:call-template name="href"/></xsl:otherwise>
          </xsl:choose>
      </a>
     <xsl:apply-templates select="." mode="add-link-highlight-at-end"/>
     </strong>
     <br/><xsl:value-of select="$newline"/>
     <!--add the description on the next line, like a summary-->
     <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
   </xsl:element><xsl:value-of select="$newline"/>
</xsl:template>


<!--ordered child processing-->
<xsl:template match="*[@collection-type='sequence']/*[contains(@class, ' topic/link ')][@role='child' or @role='descendant']" priority="3" name="topic.link_orderedchild">
    <xsl:variable name="el-name">
        <xsl:choose>
            <xsl:when test="contains(../@class,' topic/linklist ')">div</xsl:when>
            <xsl:otherwise>li</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    <xsl:element name="{$el-name}">
       <xsl:attribute name="class">olchildlink</xsl:attribute>
       <!-- Allow for unknown metadata (future-proofing) -->
       <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>
     <xsl:apply-templates select="." mode="related-links:ordered.child.prefix"/>
     <xsl:apply-templates select="." mode="add-link-highlight-at-start"/>
     <a>
          <xsl:apply-templates select="." mode="add-linking-attributes"/>
          <xsl:apply-templates select="." mode="add-hoverhelp-to-child-links"/>

          <!--use linktext as linktext if it exists, otherwise use href as linktext-->
          <xsl:choose>
          <xsl:when test="*[contains(@class, ' topic/linktext ')]"><xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/></xsl:when>
          <xsl:otherwise><!--use href--><xsl:call-template name="href"/></xsl:otherwise>
          </xsl:choose>
      </a>
     <xsl:apply-templates select="." mode="add-link-highlight-at-end"/>
      <br/><xsl:value-of select="$newline"/>
     <!--add the description on a new line, unlike an info, to avoid issues with punctuation (adding a period)-->
     <xsl:apply-templates select="*[contains(@class, ' topic/desc ')]"/>
   </xsl:element><xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/link ')]" name="topic.link">
  <xsl:choose>
    <!-- Linklist links put out <br/> in "processlinklist" -->
    <xsl:when test="ancestor::*[contains(@class,' topic/linklist ')]">
      <xsl:call-template name="makelink"/>
    </xsl:when>
    <!-- Ancestor links go in the breadcrumb trail, and should not get a <br/> -->
    <xsl:when test="@role='ancestor'">
      <xsl:call-template name="makelink"/>
    </xsl:when>
    <!-- Items with these roles should always go to output, and are not included in the hideduplicates key. -->
    <xsl:when test="@role and not(@role='cousin' or @role='external' or @role='friend' or @role='other' or @role='sample' or @role='sibling')">
      <div><xsl:call-template name="makelink"/></div><xsl:value-of select="$newline"/>
    </xsl:when>
    <!-- If roles do not match, but nearly everything else does, skip the link. -->
    <xsl:when test="(key('hideduplicates', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ',@href,@scope,@audience,@platform,@product,@otherprops,@rev,@type, normalize-space(string-join(*, ' ')))))[2]">
      <xsl:choose>
        <xsl:when test="generate-id(.)=generate-id((key('hideduplicates', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ',@href,@scope,@audience,@platform,@product,@otherprops,@rev,@type, normalize-space(string-join(*, ' ')))))[1])">
          <div><xsl:call-template name="makelink"/></div><xsl:value-of select="$newline"/>
        </xsl:when>
        <!-- If this is filtered out, we may need the duplicate link message anyway. -->
        <xsl:otherwise><xsl:call-template name="linkdupinfo"/></xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise><div><xsl:call-template name="makelink"/></div><xsl:value-of select="$newline"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--creating the actual link-->
<xsl:template name="makelink">
  <xsl:call-template name="linkdupinfo"/>
  <xsl:apply-templates select="." mode="add-link-highlight-at-start"/>
          <a>
             <xsl:apply-templates select="." mode="add-linking-attributes"/>
             <xsl:apply-templates select="." mode="add-desc-as-hoverhelp"/>
             <!-- Allow for unknown metadata (future-proofing) -->
             <xsl:apply-templates select="*[contains(@class,' topic/data ') or contains(@class,' topic/foreign ')]"/>
          <!--use linktext as linktext if it exists, otherwise use href as linktext-->
          <xsl:choose>
          <xsl:when test="*[contains(@class, ' topic/linktext ')]"><xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]"/></xsl:when>
          <xsl:otherwise><!--use href--><xsl:call-template name="href"/></xsl:otherwise>
          </xsl:choose>
       </a>
          <xsl:apply-templates select="." mode="add-link-highlight-at-end"/>
</xsl:template>

<!--process linktext elements by explicitly ignoring them and applying templates to their content; otherwise flagged as unprocessed content by the dit2htm transform-->
<xsl:template match="*[contains(@class, ' topic/linktext ')]" name="topic.linktext">
  <xsl:apply-templates select="*|text()"/>
</xsl:template>

<!--process link desc by explicitly ignoring them and applying templates to their content; otherwise flagged as unprocessed content by the dit2htm transform-->
<xsl:template match="*[contains(@class, ' topic/link ')]/*[contains(@class, ' topic/desc ')]" name="topic.link_desc">
  <xsl:apply-templates select="*|text()"/>
</xsl:template>

<!--linklists-->
<xsl:template match="*[contains(@class,' topic/linklist ')]" name="topic.linklist">
   <xsl:value-of select="$newline"/>
   <xsl:choose>
     <!--if this is a first-level linklist with no child links in it, put it in a div (flush left)-->
     <xsl:when test="parent::*[contains(@class,' topic/related-links ')] and not(child::*[contains(@class,' topic/link ')][@role='child' or @role='descendant'])">
          <div class="linklist"><xsl:apply-templates select="." mode="processlinklist"/></div>
     </xsl:when>
     <!-- When it contains children, indent with child class -->
     <xsl:when test="child::*[contains(@class,' topic/link ')][@role='child' or @role='descendant']">
         <div class="linklistwithchild">
           <xsl:apply-templates select="." mode="processlinklist">
             <xsl:with-param name="default-list-type" select="'linklistwithchild'"/>
           </xsl:apply-templates>
         </div>
     </xsl:when>
     <!-- It is a nested linklist, indent with other class -->
     <xsl:otherwise>
       <div class="sublinklist">
         <xsl:apply-templates select="." mode="processlinklist">
           <xsl:with-param name="default-list-type" select="'sublinklist'"/>
         </xsl:apply-templates>
       </div>
     </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- Omit any descendants of linklist from unordered related links (handled by topic.linklist template). -->
<xsl:key name="omit-from-unordered-links" match="*[ancestor::*[contains(@class,' topic/linklist ')]]" use="1"/>

<xsl:template name="processlinklist">
  <xsl:apply-templates select="." mode="processlinklist"/>
</xsl:template>
<xsl:template match="*" mode="processlinklist">
         <xsl:param name="default-list-type" select="'linklist'"/>
         <xsl:apply-templates select="*[contains(@class, ' topic/title ')]"/>
         <xsl:apply-templates select="*[contains(@class,' topic/desc ')]"/>
         <xsl:for-each select="*[contains(@class,' topic/linklist ')]|*[contains(@class,' topic/link ')]">
             <xsl:choose>
                 <!-- for children, div wrapper is created in main template -->
                 <xsl:when test="contains(@class,' topic/link ') and (@role='child' or @role='descendant')">
                     <xsl:value-of select="$newline"/><xsl:apply-templates select="."/>
                 </xsl:when>
                 <xsl:when test="contains(@class,' topic/link ')">
                     <xsl:value-of select="$newline"/><div><xsl:apply-templates select="."/></div>
                 </xsl:when>
                 <xsl:otherwise> <!-- nested linklist -->
                     <xsl:apply-templates select="."/>
                 </xsl:otherwise>
             </xsl:choose>
         </xsl:for-each>
         <xsl:apply-templates select="*[contains(@class,' topic/linkinfo ')]"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/linkinfo ')]" name="topic.linkinfo">
  <xsl:apply-templates/><br/><xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/linklist ')]/*[contains(@class, ' topic/title ')]" name="topic.linklist_title">
  <strong><xsl:apply-templates/></strong><br/><xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class, ' topic/linklist ')]/*[contains(@class, ' topic/desc ')]" name="topic.linklist_desc">
  <xsl:apply-templates/><br/><xsl:value-of select="$newline"/>
</xsl:template>


<xsl:template name="linkdupinfo">
  <xsl:if test="(key('linkdup', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href)))[2]">
    <xsl:if test="generate-id(.)=generate-id((key('linkdup', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href)))[1])">
      <!-- If the link is exactly the same, do not output message.  The duplicate will automatically be removed. -->
      <xsl:if test="not(key('link', concat(ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id, ' ', @href,@type,@role,@platform,@audience,@importance,@outputclass,@keyref,@scope,@format,@otherrole,@product,@otherprops,@rev,@class, normalize-space(string-join(*, ' '))))[2])">
        <xsl:apply-templates select="." mode="ditamsg:link-may-be-duplicate"/>
      </xsl:if>
    </xsl:if>
  </xsl:if>
</xsl:template>

<!-- Match an xref or link and add hover help.
     Normal treatment: if desc is present and not empty, create hovertext.
     Using title (for next/previous links, etc): always create, use title or target. -->
<xsl:template match="*" mode="add-desc-as-hoverhelp">
  <xsl:if test="*[contains(@class,' topic/desc ')]">
    <xsl:variable name="hovertext">
      <xsl:apply-templates select="*[contains(@class,' topic/desc ')][1]" mode="text-only"/>
    </xsl:variable>
    <xsl:if test="normalize-space($hovertext)!=''">
      <xsl:attribute name="title">
        <xsl:value-of select="normalize-space($hovertext)"/>
      </xsl:attribute>
    </xsl:if>
  </xsl:if>
</xsl:template>
<xsl:template match="*" mode="add-title-as-hoverhelp">
  <!--use link element's linktext as hoverhelp-->
  <xsl:attribute name="title">
    <xsl:choose>
      <xsl:when test="*[contains(@class, ' topic/linktext ')]"><xsl:value-of select="normalize-space(*[contains(@class, ' topic/linktext ')])"/></xsl:when>
      <xsl:otherwise><xsl:call-template name="href"/></xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:template>
<xsl:template match="*" mode="add-hoverhelp-to-child-links">
  <!-- By default, desc comes out inline, so no hover help is added.
       Can override this template to add hover help to child links. -->
</xsl:template>

<!-- DEPRECATED: use mode template instead -->
<xsl:template name="add-linking-attributes">
  <xsl:if test="@href and normalize-space(@href)!=''">
    <xsl:attribute name="href">
      <xsl:call-template name="href" />
    </xsl:attribute>
  </xsl:if>
  <xsl:call-template name="add-link-target-attribute" />
  <xsl:call-template name="add-user-link-attributes" />
</xsl:template>

<!-- this template is dedicated to linking based attributes, and
     allows the common linking set to be used when commonattributes
     already exists for an ancestor. -->
<xsl:template match="*" mode="add-linking-attributes">
  <xsl:apply-templates select="." mode="add-href-attribute"/>
  <xsl:apply-templates select="." mode="add-link-target-attribute"/>
  <xsl:apply-templates select="." mode="add-custom-link-attributes"/>
</xsl:template>

<xsl:template match="*" mode="add-href-attribute">
  <xsl:if test="@href and normalize-space(@href)!=''">
    <xsl:attribute name="href">
      <xsl:apply-templates select="." mode="determine-final-href"/>
    </xsl:attribute>
  </xsl:if>
</xsl:template>

<xsl:template name="add-link-target-attribute">
  <!-- DEPRECATED: use mode template -->
  <xsl:apply-templates select="." mode="add-link-target-attribute"/>
</xsl:template>
<xsl:template match="*" mode="add-link-target-attribute">
  <xsl:if test="@scope='external' or @type='external' or ((@format='PDF' or @format='pdf') and not(@scope='local'))">
    <xsl:attribute name="target">_blank</xsl:attribute>
  </xsl:if>
</xsl:template>

<xsl:template name="add-user-link-attributes">
  <!-- stub for user values. DEPRECATED - use mode template instead. -->
  <xsl:apply-templates select="." mode="add-custom-link-attributes"/>
</xsl:template>

<xsl:template match="*" mode="ditamsg:unknown-extension">
  <xsl:param name="href" select="@href"/>
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX006E'"/>
    <xsl:with-param name="msgparams">%1=<xsl:value-of select="$href"/></xsl:with-param>
  </xsl:call-template>
</xsl:template>
<xsl:template match="*" mode="ditamsg:link-may-be-duplicate">
  <xsl:param name="href" select="@href"/>
  <xsl:param name="outfile">
    <xsl:call-template name="replace-extension">
      <xsl:with-param name="filename" select="$FILENAME"/>
      <xsl:with-param name="extension" select="$OUTEXT"/>
      <xsl:with-param name="ignore-fragment" select="true()"/>
    </xsl:call-template>
  </xsl:param>
  <xsl:call-template name="output-message">
    <xsl:with-param name="id" select="'DOTX043I'"/>
    <xsl:with-param name="msgparams">%1=<xsl:value-of select="$href"/>;%2=<xsl:value-of select="$outfile"/></xsl:with-param>
  </xsl:call-template>
</xsl:template>

</xsl:stylesheet>

