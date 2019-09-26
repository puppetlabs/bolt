/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2018 Jarno Elovirta
 *
 * See the accompanying LICENSE file for applicable license.
 */

package org.dita.dost.pdf2;

import org.apache.tools.ant.BuildEvent;
import org.apache.tools.ant.BuildListener;
import org.apache.tools.ant.Project;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.Assert.assertEquals;

public class AhfLogProcessorTaskTest {

    private Path file;
    private AhfLogProcessorTask task;
    private List<String> log;

    @Before
    public void setUp() throws IOException {
        file = Files.createTempFile("ah", "log");
        task = new AhfLogProcessorTask();
        log = new ArrayList<>();
        final Project project = new Project();
        project.addBuildListener(new BuildListener() {
            @Override
            public void buildStarted(BuildEvent event) {
            }

            @Override
            public void buildFinished(BuildEvent event) {
            }

            @Override
            public void targetStarted(BuildEvent event) {
            }

            @Override
            public void targetFinished(BuildEvent event) {
            }

            @Override
            public void taskStarted(BuildEvent event) {
            }

            @Override
            public void taskFinished(BuildEvent event) {
            }

            @Override
            public void messageLogged(BuildEvent event) {
                log.add(event.getMessage());
            }
        });
        task.setProject(project);
        task.setFile(file.toFile());
    }

    @Test
    public void testSingleEmpty() {
        task.execute();
        assertEquals(0, log.size());
    }

    @Test
    public void testCommandLine() throws IOException {
        Files.write(file, Arrays.asList("foo"), StandardOpenOption.APPEND);
        task.execute();
        assertEquals(Arrays.asList("foo"), log);
    }

    @Test
    public void testProductLine() throws IOException {
        Files.write(file, Arrays.asList("foo", "bar"), StandardOpenOption.APPEND);
        task.execute();
        assertEquals(Arrays.asList("foo", "bar"), log);
    }

    @Test
    public void testCopyrightLine() throws IOException {
        Files.write(file, Arrays.asList("foo", "bar", "baz"), StandardOpenOption.APPEND);
        task.execute();
        assertEquals(Arrays.asList("foo", "bar", "baz"), log);
    }

    @Test
    public void testMessages() throws IOException {
        Files.write(file, Arrays.asList("foo", "bar", "baz", "qux", "quxx"), StandardOpenOption.APPEND);
        task.execute();
        assertEquals(Arrays.asList("foo", "bar", "baz", "quxx"), log);
    }

    @Test
    public void testMessagesWithPrefix() throws IOException {
        Files.write(file, Arrays.asList("foo", "AHFCmd :bar", "baz", "qux", "INFO: quxx"), StandardOpenOption.APPEND);
        task.execute();
        assertEquals(Arrays.asList("foo", "bar", "baz", "quxx"), log);
    }

    @After
    public void cleanUp() throws IOException {
        Files.delete(file);
    }

}