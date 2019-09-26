<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2010 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
    exclude-result-prefixes="related-links xs">

  <xsl:key name="link"
           match="*[contains(@class, ' topic/link ')][not(ancestor::*[contains(@class, ' topic/linklist ')])]"
           use="related-links:link(.)"/>
  <xsl:key name="hideduplicates"
           match="*[contains(@class, ' topic/link ')][not(ancestor::*[contains(@class, ' topic/linklist ')])]
                   [empty(@role) or @role = ('cousin', 'external', 'friend', 'other', 'sample', 'sibling')]"
           use="related-links:hideduplicates(.)"/>

  <xsl:function name="related-links:omit-from-unordered-links" as="xs:boolean">
    <xsl:param name="node" as="element()"/>
    <xsl:sequence select="$node/@role = ('child', 'descendant', 'next', 'previous', 'parent') or
                          $node[@importance = 'required' and (empty(@role) or @role = ('sibling', 'friend', 'cousin'))] or
                          $node/ancestor::*[contains(@class, ' topic/linklist ')]"/>
  </xsl:function>
  
  <xsl:function name="related-links:hideduplicates" as="xs:string">
    <xsl:param name="link" as="element()"/>
    <xsl:value-of select="concat($link/ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id,
                                 ' ',
                                 $link/@href,
                                 $link/@scope,
                                 $link/@audience,
                                 $link/@platform,
                                 $link/@product,
                                 $link/@otherprops,
                                 $link/@rev,
                                 $link/@type,
                                 normalize-space(string-join($link/*, ' ')))"/>
  </xsl:function>
  
  <xsl:function name="related-links:link" as="xs:string">
    <xsl:param name="link" as="element()"/>
    <xsl:value-of select="concat($link/ancestor::*[contains(@class, ' topic/related-links ')]/parent::*[contains(@class, ' topic/topic ')]/@id,
                                 ' ',
                                 $link/@href,
                                 $link/@type,
                                 $link/@role,
                                 $link/@platform,
                                 $link/@audience,
                                 $link/@importance,
                                 $link/@outputclass,
                                 $link/@keyref,
                                 $link/@scope,
                                 $link/@format,
                                 $link/@otherrole,
                                 $link/@product,
                                 $link/@otherprops,
                                 $link/@rev,
                                 $link/@class,
                                 $link/../@collection-type,
                                 normalize-space(string-join($link/*, ' ')))"/>
  </xsl:function>

    <!-- Ungrouped links have a priority of zero.  (Can be overridden.) -->
    <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:get-group-priority"
        name="related-links:group-priority." as="xs:integer">
        <xsl:sequence select="0"/>
    </xsl:template>

    <!-- Ungrouped links belong to the no-name group.  (Can be overridden.)  -->
    <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:get-group" name="related-links:group." as="xs:string">
        <xsl:text/>
    </xsl:template>

    <!-- Without a group, links are emitted as-is.  (Can be overridden.) -->
    <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:result-group"
                  name="related-links:group-result." as="element()?">
        <xsl:param name="links" as="node()*"/>
        <xsl:if test="exists($links)">
          <linklist class="- topic/linklist " outputclass="relinfo relref">
            <xsl:copy-of select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
            <xsl:sequence select="$links"/>
          </linklist>
        </xsl:if>
    </xsl:template>

    <!-- Ungrouped links have the default-mode template applied to them. (Can be overridden.) -->
    <xsl:template match="*[contains(@class, ' topic/link ')]" mode="related-links:link" name="related-links:link"
                  as="element()*">
      <xsl:sequence select="."/>
    </xsl:template>

    <!-- Main entry point. -->
    <xsl:template match="*[contains(@class, ' topic/related-links ')]" mode="related-links:group-unordered-links"
                  as="element()*">
        <!-- Node set.  The set of nodes to group. -->
        <xsl:param name="nodes" as="element()*"/>
        <!-- Sent back to all callback templates as a parameter.-->
        <!-- XXX: Seems obsolete as the value is never used anywhere -->
        <xsl:param name="tunnel"/>

        <!-- Query all links for their group and priority. -->
        <xsl:variable name="group-priorities" as="xs:string">
            <xsl:call-template name="related-links:get-priorities">
                <xsl:with-param name="nodes" select="$nodes"/>
                <xsl:with-param name="tunnel" select="$tunnel"/>
            </xsl:call-template>
       </xsl:variable>

        <!-- Get order of groups based on priorities. -->
        <xsl:variable name="group-sequence" as="xs:string">
            <xsl:call-template name="related-links:get-sequence-from-priorities">
                <xsl:with-param name="priorities" select="$group-priorities"/>
                <xsl:with-param name="tunnel" select="$tunnel"/>
            </xsl:call-template>
        </xsl:variable>

        <!-- Process the links in each group in order. -->
        <xsl:call-template name="related-links:walk-groups">
            <xsl:with-param name="nodes" select="$nodes"/>
            <xsl:with-param name="group-sequence" select="$group-sequence"/>
            <xsl:with-param name="tunnel" select="$tunnel"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Get the priorities and groups of every link. -->
    <!-- Produces a string like "2 task task ;3 concept concept ;1 reference reference ;0  topic ;",
         where the numbers are priorities of each group, and the space-delimited words
         are the groups and link types (link/@type) which belong to that group. -->
    <xsl:template name="related-links:get-priorities" as="xs:string">
        <xsl:param name="nodes" as="element()*"/>
        <xsl:param name="tunnel"/>
        <xsl:param name="partial-result" select="''" as="xs:string"/>

        <xsl:choose>
            <xsl:when test="exists($nodes)">
                <!-- Process each node one at a time. -->
                <xsl:variable name="node" select="$nodes[1]" as="element()"/>
                <xsl:variable name="node-group" as="xs:string">
                    <xsl:apply-templates select="$node" mode="related-links:get-group">
                        <xsl:with-param name="tunnel" select="$tunnel"/>
                    </xsl:apply-templates>
                </xsl:variable>
                <xsl:variable name="node-priorty" as="xs:integer">
                    <xsl:apply-templates select="$node" mode="related-links:get-group-priority">
                        <xsl:with-param name="tunnel" select="$tunnel"/>
                    </xsl:apply-templates>
                </xsl:variable>
                <xsl:call-template name="related-links:get-priorities">
                    <xsl:with-param name="nodes" select="$nodes[position() != 1]"/>
                    <xsl:with-param name="tunnel" select="$tunnel"/>
                    <xsl:with-param name="partial-result">
                      <xsl:value-of>
                        <xsl:choose>
                            <!-- This type has already been seen. -->
                            <xsl:when
                                test="contains($partial-result, concat(' ', $node-group, ' '))
                                and contains($partial-result, concat(' ', $node/@type, ' '))">
                                <xsl:value-of select="$partial-result"/>
                            </xsl:when>
                            <!-- This type has not been seen, but the base group has. -->
                            <xsl:when test="contains($partial-result, concat(' ', $node-group, ' '))">
                                <xsl:value-of select="substring-before($partial-result, concat(' ', $node-group, ' '))"/>
                                <xsl:text> </xsl:text>
                                <xsl:value-of select="$node-group"/>
                                <xsl:text> </xsl:text>
                                <xsl:value-of select="$node/@type"/>
                                <xsl:text> </xsl:text>
                                <xsl:value-of select="substring-after($partial-result, concat(' ', $node-group, ' '))"/>
                            </xsl:when>
                            <!-- Never seen this base group before (nor the type). -->
                            <xsl:otherwise>
                                <xsl:value-of select="$partial-result"/>
                                <xsl:value-of select="$node-priorty"/>
                                <xsl:text> </xsl:text>
                                <xsl:value-of select="$node-group"/>
                                <xsl:if test="$node-group != $node/@type">
                                    <xsl:text> </xsl:text>
                                    <xsl:value-of select="$node/@type"/>
                                </xsl:if>
                                <xsl:text> </xsl:text>
                                <xsl:text>;</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                      </xsl:value-of>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$partial-result"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Sort groups according to their priorities, removing duplicates. -->
    <!-- Takes a string returned by related-links:get-priorities and returns
         the groups and link types in decreasing order of priority
         (e.g., "concept concept;task task;reference reference; topic;"). -->
    <xsl:template name="related-links:get-sequence-from-priorities" as="xs:string">
        <xsl:param name="priorities" as="xs:string"/>
        <xsl:param name="tunnel"/>
        <xsl:param name="partial-result" select="''" as="xs:string"/>

        <xsl:choose>
            <xsl:when test="contains($priorities, ';')">
                <xsl:call-template name="related-links:get-best-priority-in-sequence">
                    <xsl:with-param name="priorities" select="$priorities"/>
                    <xsl:with-param name="tunnel" select="$tunnel"/>
                    <xsl:with-param name="partial-result" select="$partial-result"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$partial-result"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Find the highest-priority group remaining in the list of priorities. -->
    <xsl:template name="related-links:get-best-priority-in-sequence"  as="xs:string">
        <!-- semicolon separated list of space separated tuple of priority integer and group name -->
        <xsl:param name="priorities" as="xs:string"/>
        <xsl:param name="tunnel"/>
        <xsl:param name="partial-result" as="xs:string"/>
        <xsl:param name="best-group" select="'#none#'" as="xs:string"/>
        <xsl:param name="best-priority" select="-1" as="xs:integer"/>
        <!-- semicolon separated list of space separated tuple of priority integer and group name -->
        <xsl:param name="lesser-priorities" select="''" as="xs:string"/>

        <xsl:choose>
            <xsl:when test="contains($priorities, ';')">
                <xsl:choose>
                    <!-- First group always wins. -->
                    <xsl:when test="$best-group = '#none#'">
                        <xsl:call-template name="related-links:get-best-priority-in-sequence">
                            <xsl:with-param name="priorities" select="substring-after($priorities, ';')"/>
                            <xsl:with-param name="tunnel" select="$tunnel"/>
                            <xsl:with-param name="partial-result" select="$partial-result"/>
                            <xsl:with-param name="best-priority" select="xs:integer(substring-before(substring-before($priorities, ';'), ' '))"/>
                            <xsl:with-param name="best-group" select="substring-after(substring-before($priorities, ';'), ' ')"/>
                            <xsl:with-param name="lesser-priorities" select="$lesser-priorities"/>
                        </xsl:call-template>
                    </xsl:when>
                    <!-- Higher-priority group found; shunt best-so-far to lesser priorities and continue. -->
                    <xsl:when test="xs:integer(substring-before(substring-before($priorities, ';'), ' ')) > $best-priority">
                        <xsl:call-template name="related-links:get-best-priority-in-sequence">
                            <xsl:with-param name="priorities" select="substring-after($priorities, ';')"/>
                            <xsl:with-param name="tunnel" select="$tunnel"/>
                            <xsl:with-param name="partial-result" select="$partial-result"/>
                            <xsl:with-param name="best-priority" select="xs:integer(substring-before(substring-before($priorities, ';'), ' '))"/>
                            <xsl:with-param name="best-group" select="substring-after(substring-before($priorities, ';'), ' ')"/>
                            <xsl:with-param name="lesser-priorities" select="concat($lesser-priorities, $best-priority, ' ', $best-group, ';')"/>
                        </xsl:call-template>
                    </xsl:when>
                    <!-- Best-so-far priority is still supreme. -->
                    <xsl:otherwise>
                        <xsl:call-template name="related-links:get-best-priority-in-sequence">
                            <xsl:with-param name="priorities" select="substring-after($priorities, ';')"/>
                            <xsl:with-param name="tunnel" select="$tunnel"/>
                            <xsl:with-param name="partial-result" select="$partial-result"/>
                            <xsl:with-param name="best-priority" select="$best-priority"/>
                            <xsl:with-param name="best-group" select="$best-group"/>
                            <xsl:with-param name="lesser-priorities" select="concat($lesser-priorities, substring-before($priorities, ';'), ';')"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <!-- Best priority found. -->
            <xsl:otherwise>
                <xsl:call-template name="related-links:get-sequence-from-priorities">
                    <xsl:with-param name="priorities" select="$lesser-priorities"/>
                    <xsl:with-param name="tunnel" select="$tunnel"/>
                    <xsl:with-param name="partial-result">
                        <xsl:choose>
                            <!-- Duplicate; just move on.  (Should not happen.) -->
                            <xsl:when test="contains(concat(';', $partial-result), concat(';', $best-group, ';'))">
                                <xsl:value-of select="$partial-result"/>
                            </xsl:when>
                            <!-- Add group to list and move on. -->
                            <xsl:otherwise>
                                <xsl:value-of select="concat($partial-result, $best-group, ';')"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Process each group in turn. -->
  <xsl:template name="related-links:walk-groups" as="element()*">
        <xsl:param name="nodes" as="element()*"/>
        <xsl:param name="tunnel"/>
        <!-- semicolon separate list -->
        <xsl:param name="group-sequence" select="''" as="xs:string"/>

        <xsl:choose>
            <xsl:when test="contains($group-sequence, ';')">
                <xsl:call-template name="related-links:do-group">
                    <xsl:with-param name="nodes" select="$nodes"/>
                    <xsl:with-param name="tunnel" select="$tunnel"/>
                    <xsl:with-param name="group" select="substring-before($group-sequence, ';')"/>
                </xsl:call-template>
                <xsl:call-template name="related-links:walk-groups">
                    <xsl:with-param name="nodes" select="$nodes"/>
                    <xsl:with-param name="tunnel" select="$tunnel"/>
                    <xsl:with-param name="group-sequence" select="substring-after($group-sequence, ';')"/>
                </xsl:call-template>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <!-- Process each group. -->
    <xsl:template name="related-links:do-group" as="element()?">
        <xsl:param name="nodes" as="element()*"/>
        <xsl:param name="tunnel"/>
        <!-- space separated list -->
        <xsl:param name="group" as="xs:string"/>

        <!-- Process the links belonging to that group.  -->
        <xsl:variable name="group-nodes" select="$nodes[contains(concat(' ', $group), concat(' ', @type, ' '))]" as="element()*"/>
        <!-- Let the group wrap all its links in additional elements. -->
        <xsl:apply-templates select="$group-nodes[1]" mode="related-links:result-group">
            <xsl:with-param name="links" as="node()*">
                <xsl:apply-templates select="$group-nodes" mode="related-links:link">
                    <xsl:sort
                        select="
                        10 * number(@role = 'parent') + 
                        9 * number(@role = 'ancestor') + 
                        8 * number(@role = 'child') + 
                        7 * number(@role = 'descendant') + 
                        6 * number(@role = 'next') + 
                        5 * number(@role = 'previous') + 
                        4 * number(@role = 'sibling') + 
                        3 * number(@role = 'cousin') + 
                        2 * number(@role = 'friend') + 
                        1 * number(@role = 'other')"
                        data-type="number" order="descending"/>
                    <!-- All @role='other' have to go together, darn. -->
                    <xsl:sort select="@otherrole" data-type="text"/>
                    <xsl:with-param name="tunnel" select="$tunnel"/>
                </xsl:apply-templates>
            </xsl:with-param>
            <xsl:with-param name="tunnel" select="$tunnel"/>
        </xsl:apply-templates>
    </xsl:template>

</xsl:stylesheet>
