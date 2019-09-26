<?xml version='1.0'?>

<!-- 
Copyright © 2004-2006 by Idiom Technologies, Inc. All rights reserved. 
IDIOM is a registered trademark of Idiom Technologies, Inc. and WORLDSERVER
and WORLDSTART are trademarks of Idiom Technologies, Inc. All other 
trademarks are the property of their respective owners. 

IDIOM TECHNOLOGIES, INC. IS DELIVERING THE SOFTWARE "AS IS," WITH 
ABSOLUTELY NO WARRANTIES WHATSOEVER, WHETHER EXPRESS OR IMPLIED,  AND IDIOM
TECHNOLOGIES, INC. DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
PURPOSE AND WARRANTY OF NON-INFRINGEMENT. IDIOM TECHNOLOGIES, INC. SHALL NOT
BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, COVER, PUNITIVE, EXEMPLARY,
RELIANCE, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF 
ANTICIPATED PROFIT), ARISING FROM ANY CAUSE UNDER OR RELATED TO  OR ARISING 
OUT OF THE USE OF OR INABILITY TO USE THE SOFTWARE, EVEN IF IDIOM
TECHNOLOGIES, INC. HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. 

Idiom Technologies, Inc. and its licensors shall not be liable for any
damages suffered by any person as a result of using and/or modifying the
Software or its derivatives. In no event shall Idiom Technologies, Inc.'s
liability for any damages hereunder exceed the amounts received by Idiom
Technologies, Inc. as a result of this transaction.

These terms and conditions supersede the terms and conditions in any
licensing agreement to the extent that such terms and conditions conflict
with those set forth herein.

This file is part of the DITA Open Toolkit project. 
See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:opentopic="http://www.idiominc.com/opentopic"
    exclude-result-prefixes="opentopic xs"
    version="2.0">

     <xsl:template name="processTopicPreface">
         <xsl:variable name="expectedPrefaceContext" as="xs:boolean" 
             select="empty(parent::*[contains(@class,' topic/topic ')])"/>
         <xsl:choose>
             <xsl:when test="$expectedPrefaceContext">
                 <fo:page-sequence master-reference="body-sequence" xsl:use-attribute-sets="page-sequence.preface">
                     <xsl:call-template name="insertPrefaceStaticContents"/>
                     <fo:flow flow-name="xsl-region-body">
                         <xsl:apply-templates select="." mode="processTopicPrefaceInsideFlow"/>
                     </fo:flow>
                 </fo:page-sequence>
             </xsl:when>
             <xsl:otherwise>
                 <xsl:apply-templates select="." mode="processTopicPrefaceInsideFlow"/>
             </xsl:otherwise>
         </xsl:choose>
     </xsl:template>
     <xsl:template match="*" mode="processTopicPrefaceInsideFlow">
         <fo:block xsl:use-attribute-sets="topic">
             <xsl:call-template name="commonattributes"/>
             <xsl:if test="not(ancestor::*[contains(@class, ' topic/topic ')])">
                 <fo:marker marker-class-name="current-topic-number">
                     <xsl:number format="1"/>
                 </fo:marker>
                 <xsl:apply-templates select="." mode="insertTopicHeaderMarker"/>
             </xsl:if>
             <xsl:apply-templates select="." mode="customTopicMarker"/>
             <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]"/>
             <xsl:apply-templates select="." mode="insertChapterFirstpageStaticContent">
                 <xsl:with-param name="type" select="'preface'"/>
             </xsl:apply-templates>
             <fo:block xsl:use-attribute-sets="topic.title">
                 <xsl:apply-templates select="." mode="customTopicAnchor"/>
                 <xsl:call-template name="pullPrologIndexTerms"/>
                 <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]"/>
                 <xsl:for-each select="child::*[contains(@class,' topic/title ')]">
                     <xsl:apply-templates select="." mode="getTitle"/>
                 </xsl:for-each>
             </fo:block>
             <xsl:apply-templates select="*[not(contains(@class,' topic/title ') or contains(@class,' ditaot-d/ditaval-startprop '))]"/>
         </fo:block>
     </xsl:template>

</xsl:stylesheet>