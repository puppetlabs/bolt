<?xml version='1.0'?>

<!--
Copyright ? 2004-2006 by Idiom Technologies, Inc. All rights reserved.
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
    xmlns:dita2xslfo="http://dita-ot.sourceforge.net/ns/200910/dita2xslfo"
    xmlns:opentopic="http://www.idiominc.com/opentopic"
    xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
    exclude-result-prefixes="opentopic opentopic-index dita2xslfo"
    version="2.0">

    <!-- Determines whether to generate titles for task sections. Values are YES and NO. -->
    <xsl:param name="GENERATE-TASK-LABELS">
        <xsl:choose>
            <xsl:when test="$antArgsGenerateTaskLabels='YES'"><xsl:value-of select="$antArgsGenerateTaskLabels"/></xsl:when>
            <xsl:otherwise>NO</xsl:otherwise>
        </xsl:choose>
    </xsl:param>
  
  <xsl:template match="*[contains(@class, ' task/task ')]" mode="processTopic"
                name="processTask">
    <fo:block xsl:use-attribute-sets="task">
      <xsl:apply-templates select="." mode="commonTopicProcessing"/>
    </fo:block>
  </xsl:template>
  
  <!-- Deprecated, retained for backwards compatibility -->
  <xsl:template match="*" mode="processTask">
    <xsl:call-template name="processTask"/>
  </xsl:template>
  
    <xsl:template match="*[contains(@class, ' task/taskbody ')]">
        <fo:block xsl:use-attribute-sets="taskbody">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/prereq ')]">
        <fo:block xsl:use-attribute-sets="prereq">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="dita2xslfo:task-heading">
                  <xsl:with-param name="use-label">
                    <xsl:apply-templates select="." mode="dita2xslfo:retrieve-task-heading">
                      <xsl:with-param name="pdf2-string">Task Prereq</xsl:with-param>
                      <xsl:with-param name="common-string">task_prereq</xsl:with-param>
                    </xsl:apply-templates>
                </xsl:with-param>
            </xsl:apply-templates>
            <fo:block xsl:use-attribute-sets="prereq__content">
              <xsl:apply-templates/>
            </fo:block>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/context ')]">
        <fo:block xsl:use-attribute-sets="context">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="dita2xslfo:task-heading">
                <xsl:with-param name="use-label">
                    <xsl:apply-templates select="." mode="dita2xslfo:retrieve-task-heading">
                      <xsl:with-param name="pdf2-string">Task Context</xsl:with-param>
                      <xsl:with-param name="common-string">task_context</xsl:with-param>
                    </xsl:apply-templates>
                </xsl:with-param>
            </xsl:apply-templates>
            <fo:block xsl:use-attribute-sets="context__content">
              <xsl:apply-templates/>
            </fo:block>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/cmd ')]" priority="1">
        <fo:block xsl:use-attribute-sets="cmd">
            <xsl:call-template name="commonattributes"/>
            <xsl:if test="../@importance='optional'">
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Optional Step'"/>
                </xsl:call-template>
                <xsl:text> </xsl:text>
            </xsl:if>
            <xsl:if test="../@importance='required'">
                <xsl:call-template name="getVariable">
                    <xsl:with-param name="id" select="'Required Step'"/>
                </xsl:call-template>
                <xsl:text> </xsl:text>
            </xsl:if>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/info ')]">
        <fo:block xsl:use-attribute-sets="info">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/tutorialinfo ')]">
        <fo:block xsl:use-attribute-sets="tutorialinfo">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/stepresult ')]">
        <fo:block xsl:use-attribute-sets="stepresult">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/result ')]">
        <fo:block xsl:use-attribute-sets="result">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="dita2xslfo:task-heading">
                <xsl:with-param name="use-label">
                    <xsl:apply-templates select="." mode="dita2xslfo:retrieve-task-heading">
                      <xsl:with-param name="pdf2-string">Task Result</xsl:with-param>
                      <xsl:with-param name="common-string">task_results</xsl:with-param>
                    </xsl:apply-templates>
                </xsl:with-param>
            </xsl:apply-templates>
            <fo:block xsl:use-attribute-sets="result__content">
              <xsl:apply-templates/>
            </fo:block>
        </fo:block>
    </xsl:template>

    <!-- If example has a title, process it first; otherwise, create default title (if needed) -->
    <xsl:template match="*[contains(@class, ' task/taskbody ')]/*[contains(@class, ' topic/example ')]">
        <fo:block xsl:use-attribute-sets="task.example">
            <xsl:call-template name="commonattributes"/>
            <xsl:choose>
              <xsl:when test="*[contains(@class, ' topic/title ')]">
                <xsl:apply-templates select="*[contains(@class, ' topic/title ')]"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:apply-templates select="." mode="dita2xslfo:task-heading">
                  <xsl:with-param name="use-label">
                      <xsl:apply-templates select="." mode="dita2xslfo:retrieve-task-heading">
                        <xsl:with-param name="pdf2-string">Task Example</xsl:with-param>
                        <xsl:with-param name="common-string">task_example</xsl:with-param>
                      </xsl:apply-templates>
                  </xsl:with-param>
                </xsl:apply-templates>
              </xsl:otherwise>
            </xsl:choose>
            <fo:block xsl:use-attribute-sets="task.example__content">
              <xsl:apply-templates select="*[not(contains(@class, ' topic/title '))]|text()|processing-instruction()"/>
            </fo:block>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/postreq ')]">
        <fo:block xsl:use-attribute-sets="postreq">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates select="." mode="dita2xslfo:task-heading">
                <xsl:with-param name="use-label">
                    <xsl:apply-templates select="." mode="dita2xslfo:retrieve-task-heading">
                      <xsl:with-param name="pdf2-string">Task Postreq</xsl:with-param>
                      <xsl:with-param name="common-string">task_postreq</xsl:with-param>
                    </xsl:apply-templates>
                </xsl:with-param>
            </xsl:apply-templates>
            <fo:block xsl:use-attribute-sets="postreq__content">
              <xsl:apply-templates/>
            </fo:block>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/stepxmp ')]">
        <fo:block xsl:use-attribute-sets="stepxmp">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/steps ')]" name="steps">
      <xsl:apply-templates select="." mode="dita2xslfo:task-heading">
          <xsl:with-param name="use-label">
            <xsl:apply-templates select="." mode="dita2xslfo:retrieve-task-heading">
              <xsl:with-param name="pdf2-string">Task Steps</xsl:with-param>
              <xsl:with-param name="common-string">task_procedure</xsl:with-param>
            </xsl:apply-templates>
          </xsl:with-param>
      </xsl:apply-templates>
      <xsl:choose>
        <xsl:when test="count(*[contains(@class, ' task/step ')]) eq 1">
          <fo:block>
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates mode="onestep"/>
          </fo:block>
        </xsl:when>
        <xsl:otherwise>
          <fo:list-block xsl:use-attribute-sets="steps">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
          </fo:list-block>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

  <xsl:template match="*[contains(@class, ' task/steps-unordered ')]" name="steps-unordered">
    <xsl:apply-templates select="." mode="dita2xslfo:task-heading">
      <xsl:with-param name="use-label">
        <xsl:apply-templates select="." mode="dita2xslfo:retrieve-task-heading">
          <xsl:with-param name="pdf2-string">#steps-unordered-label</xsl:with-param>
          <xsl:with-param name="common-string">task_procedure_unordered</xsl:with-param>
        </xsl:apply-templates>
      </xsl:with-param>
    </xsl:apply-templates>
    <fo:list-block xsl:use-attribute-sets="steps-unordered">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:list-block>
  </xsl:template>

    <xsl:template match="*[contains(@class, ' task/steps ')]/*[contains(@class, ' task/step ')]">
        <xsl:variable name="format">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Step Format'"/>
          </xsl:call-template>
        </xsl:variable>
        <fo:list-item xsl:use-attribute-sets="steps.step">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="steps.step__label">
                <fo:block xsl:use-attribute-sets="steps.step__label__content">
                    <xsl:if test="preceding-sibling::*[contains(@class, ' task/step ')] | following-sibling::*[contains(@class, ' task/step ')]">
                        <xsl:call-template name="getVariable">
                            <xsl:with-param name="id" select="'Step Number'"/>
                            <xsl:with-param name="params" as="element()*">
                                <number>
                                    <xsl:number format="{$format}" count="*[contains(@class, ' task/step ')]"/>
                                </number>
                            </xsl:with-param>
                        </xsl:call-template>
                    </xsl:if>
                </fo:block>
            </fo:list-item-label>

            <fo:list-item-body xsl:use-attribute-sets="steps.step__body">
                <fo:block xsl:use-attribute-sets="steps.step__content">
                    <xsl:apply-templates/>
                </fo:block>
            </fo:list-item-body>

        </fo:list-item>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/steps-unordered ')]/*[contains(@class, ' task/step ')]">
        <fo:list-item xsl:use-attribute-sets="steps-unordered.step">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="steps-unordered.step__label">
                <fo:block xsl:use-attribute-sets="steps-unordered.step__label__content">
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Unordered List bullet'"/>
                    </xsl:call-template>
                </fo:block>
            </fo:list-item-label>

            <fo:list-item-body xsl:use-attribute-sets="steps-unordered.step__body">
                <fo:block xsl:use-attribute-sets="steps-unordered.step__content">
                    <xsl:apply-templates/>
                </fo:block>
            </fo:list-item-body>

        </fo:list-item>
    </xsl:template>

  <xsl:template match="*[contains(@class, ' task/step ')]" mode="onestep">
    <fo:block xsl:use-attribute-sets="steps.step__content--onestep">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:block>
  </xsl:template>
  <xsl:template match="node()" mode="onestep" priority="-10"/>

    <xsl:template match="*[contains(@class, ' task/stepsection ')]">
        <fo:list-item xsl:use-attribute-sets="stepsection">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="stepsection__label">
              <fo:block xsl:use-attribute-sets="stepsection__label__content">
              </fo:block>
            </fo:list-item-label>

            <fo:list-item-body xsl:use-attribute-sets="stepsection__body">
                <fo:block xsl:use-attribute-sets="stepsection__content">
                    <xsl:apply-templates/>
                </fo:block>
            </fo:list-item-body>

        </fo:list-item>
    </xsl:template>

    <!--Substeps-->
    <xsl:template match="*[contains(@class, ' task/substeps ')][empty(*[contains(@class,' task/substep ')])]" priority="10"/>
  
    <xsl:template match="*[contains(@class, ' task/substeps ')]">
        <fo:list-block xsl:use-attribute-sets="substeps">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:list-block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/substeps ')]/*[contains(@class, ' task/substep ')]">
        <xsl:variable name="format">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Substep Format'"/>
          </xsl:call-template>
        </xsl:variable>
        <fo:list-item xsl:use-attribute-sets="substeps.substep">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="substeps.substep__label">
                <fo:block xsl:use-attribute-sets="substeps.substep__label__content">
                    <xsl:call-template name="getVariable">
                      <xsl:with-param name="id" select="'Substep Number'"/>
                      <xsl:with-param name="params" as="element()*">
                        <number>
                          <xsl:number format="{$format}"/>
                        </number>
                      </xsl:with-param>
                    </xsl:call-template>
                </fo:block>
            </fo:list-item-label>
            <fo:list-item-body xsl:use-attribute-sets="substeps.substep__body">
                <fo:block xsl:use-attribute-sets="substeps.substep__content">
                    <xsl:apply-templates/>
                </fo:block>
            </fo:list-item-body>
        </fo:list-item>
    </xsl:template>

    <!--Choices-->
    <xsl:template match="*[contains(@class, ' task/choices ')][empty(*[contains(@class,' task/choice ')])]" priority="10"/>
    <xsl:template match="*[contains(@class, ' task/choices ')]">
        <fo:list-block xsl:use-attribute-sets="choices">
            <xsl:call-template name="commonattributes"/>
            <xsl:apply-templates/>
        </fo:list-block>
    </xsl:template>

    <xsl:template match="*[contains(@class, ' task/choice ')]">
        <fo:list-item xsl:use-attribute-sets="choices.choice">
            <xsl:call-template name="commonattributes"/>
            <fo:list-item-label xsl:use-attribute-sets="choices.choice__label">
                <fo:block xsl:use-attribute-sets="choices.choice__label__content">
                    <xsl:call-template name="getVariable">
                        <xsl:with-param name="id" select="'Unordered List bullet'"/>
                    </xsl:call-template>
                </fo:block>
            </fo:list-item-label>
            <fo:list-item-body xsl:use-attribute-sets="choices.choice__body">
                <fo:block xsl:use-attribute-sets="choices.choice__content">
                    <xsl:apply-templates/>
                </fo:block>
            </fo:list-item-body>
        </fo:list-item>
    </xsl:template>

  <!-- Choice tables -->
  <xsl:template match="*[contains(@class, ' task/choicetable ')]
    [empty(*[contains(@class,' task/chrow ')]/*[contains(@class,' task/choption ') or contains(@class,' task/chdesc ')])]" priority="10"/>
  <xsl:template match="*[contains(@class, ' task/chrow ')]
    [empty(*[contains(@class,' task/choption ') or contains(@class,' task/chdesc ')])]" priority="10"/>
  <xsl:template match="*[contains(@class, ' task/choicetable ')]">
    <fo:table xsl:use-attribute-sets="choicetable">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="univAttrs"/>
      <xsl:call-template name="globalAtts"/>
      <xsl:call-template name="displayAtts">
        <xsl:with-param name="element" select="."/>
      </xsl:call-template>

      <xsl:if test="@relcolwidth">
        <xsl:variable name="fix-relcolwidth">
          <xsl:apply-templates select="." mode="fix-relcolwidth">
            <xsl:with-param name="number-cells" select="2"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:call-template name="createSimpleTableColumns">
          <xsl:with-param name="theColumnWidthes" select="$fix-relcolwidth"/>
        </xsl:call-template>
      </xsl:if>

      <xsl:choose>
        <xsl:when test="*[contains(@class, ' task/chhead ')]">
          <xsl:apply-templates select="*[contains(@class, ' task/chhead ')]"/>
        </xsl:when>
        <xsl:otherwise>
          <fo:table-header xsl:use-attribute-sets="chhead">
            <fo:table-row xsl:use-attribute-sets="chhead__row">
              <xsl:apply-templates select="." mode="emptyChoptionHd"/>
              <xsl:apply-templates select="." mode="emptyChdescHd"/>
            </fo:table-row>
          </fo:table-header>
        </xsl:otherwise>
      </xsl:choose>

      <fo:table-body xsl:use-attribute-sets="choicetable__body">
        <xsl:apply-templates select="*[contains(@class, ' task/chrow ')]"/>
      </fo:table-body>

    </fo:table>
  </xsl:template>
  
  <xsl:template match="*" mode="emptyChoptionHd">
    <fo:table-cell xsl:use-attribute-sets="chhead.choptionhd">
      <xsl:apply-templates select="." mode="simpletableHorizontalBorders"/>
      <xsl:apply-templates select="." mode="simpletableTopBorder"/>
      <xsl:apply-templates select="." mode="simpletableVerticalBorders"/>
      <fo:block xsl:use-attribute-sets="chhead.choptionhd__content">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Option'"/>
        </xsl:call-template>
      </fo:block>
    </fo:table-cell>
  </xsl:template>
  
  <xsl:template match="*" mode="emptyChdescHd">
    <fo:table-cell xsl:use-attribute-sets="chhead.chdeschd">
      <xsl:apply-templates select="." mode="simpletableHorizontalBorders"/>
      <xsl:apply-templates select="." mode="simpletableTopBorder"/>
      <fo:block xsl:use-attribute-sets="chhead.chdeschd__content">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Description'"/>
        </xsl:call-template>
      </fo:block>
    </fo:table-cell>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/chhead ')]">
    <fo:table-header xsl:use-attribute-sets="chhead">
      <xsl:call-template name="commonattributes"/>
      <fo:table-row xsl:use-attribute-sets="chhead__row">
        <xsl:if test="empty(*[contains(@class,' task/choptionhd ')])">
          <xsl:apply-templates select="." mode="emptyChoptionHd"/>
        </xsl:if>
        <xsl:apply-templates/>
        <xsl:if test="empty(*[contains(@class,' task/chdeschd ')])">
          <xsl:apply-templates select="." mode="emptyChdescHd"/>
        </xsl:if>
      </fo:table-row>
    </fo:table-header>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/chrow ')]">
    <fo:table-row xsl:use-attribute-sets="chrow">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates/>
    </fo:table-row>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/chhead ')]/*[contains(@class, ' task/choptionhd ')]">
    <fo:table-cell xsl:use-attribute-sets="chhead.choptionhd">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="." mode="simpletableHorizontalBorders"/>
      <xsl:apply-templates select="." mode="simpletableTopBorder"/>
      <xsl:apply-templates select="." mode="simpletableVerticalBorders"/>
      <fo:block xsl:use-attribute-sets="chhead.choptionhd__content">
        <xsl:apply-templates/>
      </fo:block>
    </fo:table-cell>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/chhead ')]/*[contains(@class, ' task/chdeschd ')]">
    <fo:table-cell xsl:use-attribute-sets="chhead.chdeschd">
      <xsl:call-template name="commonattributes"/>
      <xsl:apply-templates select="." mode="simpletableHorizontalBorders"/>
      <xsl:apply-templates select="." mode="simpletableTopBorder"/>
      <fo:block xsl:use-attribute-sets="chhead.chdeschd__content">
        <xsl:apply-templates/>
      </fo:block>
    </fo:table-cell>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/chrow ')]/*[contains(@class, ' task/choption ')]">
    <xsl:variable name="keyCol" select="ancestor::*[contains(@class, ' task/choicetable ')][1]/@keycol"/>
    <fo:table-cell xsl:use-attribute-sets="chrow.choption">
      <xsl:call-template name="commonattributes"/>
      <xsl:if test="../following-sibling::*[contains(@class, ' task/chrow ')]">
        <xsl:apply-templates select="." mode="simpletableHorizontalBorders"/>
      </xsl:if>
      <xsl:apply-templates select="." mode="simpletableVerticalBorders"/>
      <xsl:choose>
        <xsl:when test="$keyCol = 1">
          <fo:block xsl:use-attribute-sets="chrow.choption__keycol-content">
            <xsl:apply-templates/>
          </fo:block>
        </xsl:when>
        <xsl:otherwise>
          <fo:block xsl:use-attribute-sets="chrow.choption__content">
            <xsl:apply-templates/>
          </fo:block>
        </xsl:otherwise>
      </xsl:choose>
    </fo:table-cell>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/chrow ')]/*[contains(@class, ' task/chdesc ')]">
    <xsl:variable name="keyCol" select="number(ancestor::*[contains(@class, ' task/choicetable ')][1]/@keycol)"/>
    <fo:table-cell xsl:use-attribute-sets="chrow.chdesc">
      <xsl:call-template name="commonattributes"/>
      <xsl:if test="../following-sibling::*[contains(@class, ' task/chrow ')]">
        <xsl:apply-templates select="." mode="simpletableHorizontalBorders"/>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$keyCol = 2">
          <fo:block xsl:use-attribute-sets="chrow.chdesc__keycol-content">
            <xsl:apply-templates/>
          </fo:block>
        </xsl:when>
        <xsl:otherwise>
          <fo:block xsl:use-attribute-sets="chrow.chdesc__content">
            <xsl:apply-templates/>
          </fo:block>
        </xsl:otherwise>
      </xsl:choose>
    </fo:table-cell>
  </xsl:template>

  <!-- Example -->

  <xsl:template match="*[contains(@class, ' topic/example ')]" mode="dita2xslfo:task-heading">
    <xsl:param name="use-label"/>
    <xsl:if test="$GENERATE-TASK-LABELS='YES'">
      <fo:block xsl:use-attribute-sets="example.title">
        <fo:inline>
          <xsl:copy-of select="$use-label"/>
        </fo:inline>
      </fo:block>
    </xsl:if>
  </xsl:template>

    <xsl:template match="*" mode="dita2xslfo:task-heading">
        <xsl:param name="use-label"/>
        <xsl:if test="$GENERATE-TASK-LABELS='YES'">
            <fo:block xsl:use-attribute-sets="section.title">
                <fo:inline><xsl:copy-of select="$use-label"/></fo:inline>
            </fo:block>
        </xsl:if>
    </xsl:template>

    <!-- Set up to allow string retrieval based on the original PDF2 string;
         if not found, fall back to the common string -->
    <xsl:template match="*" mode="dita2xslfo:retrieve-task-heading">
      <xsl:param name="pdf2-string"/>
      <xsl:param name="common-string"/>
      <xsl:variable name="retrieved-pdf2-string">
        <!-- By default, will return the lookup value -->
        <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="$pdf2-string"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="$retrieved-pdf2-string!=$pdf2-string and $retrieved-pdf2-string!=''">
          <xsl:value-of select="$retrieved-pdf2-string"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="getVariable">
              <xsl:with-param name="id" select="$common-string"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
